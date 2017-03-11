########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################

<#
.Synopsis
    This script tests the file copy overwrite functionality.

.Description
    The script will copy a file from a Windows host to the Linux VM,
    and checks if the size is matching.
	Then it tries to copy the same file again, which must fail with an
	error message that the file already exists - error code 0x80070050.

    A typical XML definition for this test case would look similar
    to the following:
		<test>
			<testName>FCOPY_file_exists</testName>
			<testScript>setupscripts\FCOPY_file_exists.ps1</testScript>
			<timeout>900</timeout>
			<testParams>
				<param>TC_COVERED=FCopy-02</param>
			</testParams>
			<noReboot>True</noReboot>
		</test>

.Parameter vmName
    Name of the VM to test.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    Test data for this test case.

.Example
    setupScripts\FCOPY_file_exists.ps1 -vmName NameOfVm -hvServer localhost -testParams 'sshKey=path/to/ssh;ipv4=ipaddress'
#>

param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $false
$testfile = $null
$gsi = $null

#######################################################################
#
#	Main body script
#
#######################################################################
# Checking the input arguments
if (-not $vmName) {
    "Error: VM name is null!"
    return $retVal
}

if (-not $hvServer) {
    "Error: hvServer is null!"
    return $retVal
}

if (-not $testParams) {
    "Error: No testParams provided!"
    "This script requires the test case ID and VM details as the test parameters."
    return $retVal
}

#
# Checking the mandatory testParams. New parameters must be validated here.
#
$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")
    
    if ($fields[0].Trim() -eq "TC_COVERED") {
        $TC_COVERED = $fields[1].Trim()
    }
	if ($fields[0].Trim() -eq "ipv4") {
		$IPv4 = $fields[1].Trim()
    }
	if ($fields[0].Trim() -eq "rootDir") {
        $rootDir = $fields[1].Trim()
    }
	if ($fields[0].Trim() -eq "sshkey") {
        $sshkey = $fields[1].Trim()
    }
}

#
# Change the working directory for the log files
# Delete any previous summary.log file, then create a new one
#
if (-not (Test-Path $rootDir)) {
    "Error: The directory `"${rootDir}`" does not exist"
    return $retVal
}
cd $rootDir

# Delete any previous summary.log file, then create a new one
$summaryLog = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "This script covers test case: ${TC_COVERED}" | Tee-Object -Append -file $summaryLog

$retVal = $True

#
# Verify if the Guest services are enabled for this VM
#
$gsi = Get-VMIntegrationService -vmName $vmName -ComputerName $hvServer -Name "Guest Service Interface"
if (-not $gsi) {
    "Error: Unable to retrieve Integration Service status from VM '${vmName}'" | Tee-Object -Append -file $summaryLog
    return $False
}

if (-not $gsi.Enabled) {
    "Warning: The Guest services are not enabled for VM '${vmName}'" | Tee-Object -Append -file $summaryLog
	if ((Get-VM -ComputerName $hvServer -Name $vmName).State -ne "Off") {
		Stop-VM -ComputerName $hvServer -Name $vmName -Force -Confirm:$false
	}

	# Waiting until the VM is off
	while ((Get-VM -ComputerName $hvServer -Name $vmName).State -ne "Off") {
		Start-Sleep -Seconds 5
	}
	
	Enable-VMIntegrationService -Name "Guest Service Interface" -vmName $vmName -ComputerName $hvServer 
	Start-VM -Name $vmName -ComputerName $hvServer

	# Waiting for the VM to run again and respond to SSH - port 22
	do {
		sleep 5
	} until (Test-NetConnection $IPv4 -Port 22 -WarningAction SilentlyContinue | ? { $_.TcpTestSucceeded } )
}

# Get VHD path of tested server; file will be copied there
$vhd_path = Get-VMHost -ComputerName $hvServer | Select -ExpandProperty VirtualHardDiskPath

# Fix path format if it's broken
if ($vhd_path.Substring($vhd_path.Length - 1, 1) -ne "\"){
    $vhd_path = $vhd_path + "\"
}

$vhd_path_formatted = $vhd_path.Replace(':','$')

# Define the file-name to use with the current time-stamp
$testfile = "testfile-$(get-date -uformat '%H-%M-%S-%Y-%m-%d').file"

$filePath = $vhd_path + $testfile
$file_path_formatted = $vhd_path_formatted + $testfile


if ($gsi.OperationalStatus -ne "OK") {
    "Error: The Guest services are not working properly for VM '${vmName}'!" | Tee-Object -Append -file $summaryLog
	$retVal = $False
}
else {
	# Create a 10MB sample file
	$createfile = fsutil file createnew \\$hvServer\$file_path_formatted 10485760

	if ($createfile -notlike "File *testfile-*.file is created") {
		"Error: Could not create the sample test file in the working directory!" | Tee-Object -Append -file $summaryLog
		$retVal = $False
	}
}

# Check to see if the fcopy daemon is running on the VM
$sts = RunRemoteScript "FCOPY_Check_Daemon.sh"
if (-not $sts[-1])
{
    Write-Output "Error executing FCOPY_Check_Daemon.sh on VM. Exiting test case!" | Tee-Object -Append -file $summaryLog
    return $False
}

Remove-Item -Path "FCOPY_Check_Daemon.sh.log" -Force
Write-Output "Info: fcopy daemon is running on VM '${vmName}'"

# Removing previous test files on the VM
.\bin\plink.exe -i ssh\${sshKey} root@${ipv4} "rm -f /tmp/testfile-*"

# If we got here then all checks have passed and we can copy the file to the Linux guest VM
# Initial file copy, which must be successful
$Error.Clear()
Copy-VMFile -vmName $vmName -ComputerName $hvServer -SourcePath $filePath -DestinationPath "/tmp/" -FileSource host -ErrorAction SilentlyContinue
if ($error.Count -eq 0) {
	# Checking if the file size is matching
	$sts = CheckFile /tmp/$testfile
	if (-not $sts[-1]) {
		Write-Output "ERROR: File is not present on the guest VM '${vmName}'!" | Tee-Object -Append -file $summaryLog
		$retVal = $False
	}
	elseif ($sts[0] -eq 10485760) {
		Write-Output "Info: The file copied matches the 10MB size." | Tee-Object -Append -file $summaryLog
	}
    else {
	    Write-Output "ERROR: The file copied doesn't match the 10MB size!" | Tee-Object -Append -file $summaryLog
	    $retVal = $False
    }
}
elseif ($Error.Count -gt 0) {
	Write-Output "Test Failed. An error has occurred while copying the file to guest VM '${vmName}'!" | Tee-Object -Append -file $summaryLog
	$error[0] | Tee-Object -Append -file $summaryLog
	$retVal = $False
}

$Error.Clear()
# Second copy file attempt must fail with the below error code pattern
Copy-VMFile -vmName $vmName -ComputerName $hvServer -SourcePath $filePath -DestinationPath "/tmp/" -FileSource host -ErrorAction SilentlyContinue

if ($Error[0].Exception.Message -like "*failed to initiate copying files to the guest: The file exists. (0x80070050)*") {
	Write-Output "Test passed! File could not be copied as it already exists on guest VM '${vmName}'" | Tee-Object -Append -file $summaryLog
}
elseif ($error.Count -eq 0) {
	Write-Output "Error: File '${testfile}' has been copied twice to guest VM '${vmName}'!" | Tee-Object -Append -file $summaryLog
	$retVal = $False
}

# Removing the temporary test file
Remove-Item -Path \\$hvServer\$file_path_formatted -Force
if ($? -ne "True") {
    Write-Output "ERROR: cannot remove the test file '${testfile}'!" | Tee-Object -Append -file $summaryLog
}

return $retVal