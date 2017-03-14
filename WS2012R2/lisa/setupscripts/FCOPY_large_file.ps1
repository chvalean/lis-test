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
    This script tests the functionality of copying a 10GB large file.

.Description
    The script will copy a random generated 10GB file from a Windows host to
	the Linux VM, and then checks if the size is matching.

    A typical XML definition for this test case would look similar
    to the following:
		<test>
			<testName>FCOPY_large_file</testName>
			<setupScript>setupScripts\AddVhdxHardDisk.ps1</setupScript>
			<testScript>setupscripts\FCOPY_large_file.ps1</testScript>
            <cleanupScript>SetupScripts\RemoveVhdxHardDisk.ps1</cleanupScript>
			<timeout>900</timeout>
			<testParams>
				<param>TC_COVERED=FCopy-04</param>
				<param>SCSI=0,0,Dynamic</param>
			</testParams>
		</test>

.Parameter vmName
    Name of the VM to test.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    Test data for this test case.

.Example
    setupScripts\FCOPY_large_file.ps1 -vmName NameOfVm -hvServer localhost -testParams 'sshKey=path/to/ssh;ipv4=ipaddress'
#>

param([string] $vmName, [string] $hvServer, [string] $testParams)

$testfile = $null
$gsi = $null
# 10GB file size
$filesize = 10737418240
$retVal = $false

#######################################################################
#
#	Mount disk
#
#######################################################################
function mount_disk()
{
    . .\setupScripts\TCUtils.ps1

    $driveName = "/dev/sdb"

    $sts = SendCommandToVM $ipv4 $sshKey "(echo d;echo;echo w)|fdisk ${driveName}"
    if (-not $sts) {
		Write-Output "ERROR: Failed to format the disk in the VM $vmName."
		return $False
    }

    $sts = SendCommandToVM $ipv4 $sshKey "(echo n;echo p;echo 1;echo;echo;echo w)|fdisk ${driveName}"
    if (-not $sts) {
		Write-Output "ERROR: Failed to format the disk in the VM $vmName."
		return $False
    }

    $sts = SendCommandToVM $ipv4 $sshKey "mkfs.ext3 ${driveName}1"
    if (-not $sts) {
		Write-Output "ERROR: Failed to make file system in the VM $vmName."
		return $False
    }

    $sts = SendCommandToVM $ipv4 $sshKey "mount ${driveName}1 /mnt"
    if (-not $sts) {
		Write-Output "ERROR: Failed to mount the disk in the VM $vmName."
		return $False
    }

    "Info: $driveName has been mounted to /mnt in the VM $vmName."

    return $True
}

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
	if ($fields[0].Trim() -eq "rootDir") {
        $rootDir = $fields[1].Trim()
    }
	if ($fields[0].Trim() -eq "ipv4") {
		$IPv4 = $fields[1].Trim()
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
enable_GuestIntegrationServices()

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
	# Create a 10GB sample file
	$createfile = fsutil file createnew \\$hvServer\$file_path_formatted $filesize

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

$sts = mount_disk
if (-not $sts[-1]) {
    Write-Output "ERROR: Failed to mount the disk in the VM." | Tee-Object -Append -file $summaryLog
    $retVal = $False
}

#
# Copy the file to the Linux guest VM
#
$Error.Clear()
$copyDuration = (Measure-Command { Copy-VMFile -vmName $vmName -ComputerName $hvServer -SourcePath $filePath -DestinationPath `
    "/mnt/" -FileSource host -ErrorAction SilentlyContinue }).totalseconds

if ($Error.Count -eq 0) {
	Write-Output "Info: File has been successfully copied to guest VM '${vmName}'" | Tee-Object -Append -file $summaryLog
}
else {
	Write-Output "ERROR: File could not be copied!" | Tee-Object -Append -file $summaryLog
	$retVal = $False
}

[int]$copyDuration = [math]::floor($copyDuration)

Write-Output "The file copy process took ${copyDuration} seconds" | Tee-Object -Append -file $summaryLog

#
# Checking if the file is present on the guest and file size is matching
#
$sts = CheckFile /tmp/$testfile
if (-not $sts[-1]) {
	Write-Output "ERROR: File is not present on the guest VM '${vmName}'!" | Tee-Object -Append -file $summaryLog
	$retVal = $False
}
elseif ($sts[0] -eq $filesize) {
	Write-Output "Info: The file copied matches the 10GB size." | Tee-Object -Append -file $summaryLog
}
else {
	Write-Output "ERROR: The file copied doesn't match the 10GB size!" | Tee-Object -Append -file $summaryLog
	$retVal = $False
}

#
# Removing the temporary test file
#
Remove-Item -Path \\$hvServer\$file_path_formatted -Force
if (-not $?) {
    Write-Output "ERROR: Cannot remove the test file '${testfile}'!" | Tee-Object -Append -file $summaryLog
}

return $retVal