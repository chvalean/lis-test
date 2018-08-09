#!/bin/bash

################################################################
#
# KVP_basic_checks.sh
# Description:
# 1. verify that the KVP Daemon is running
# 2. run the KVP client tool and verify that the data pools are created and accessible
# 3. check kvp_pool file permission is 644
# 4. check kernel version supports hv_kvp
# 5. Use lsof to check the opened file number belonging to hypervkvp process does not increase
#    continually. If this number increases, maybe file descriptors are not closed properly.
#    Here check duration is after 2 minutes.
# 6. Check if KVP pool 3 file has a size greater than zero.
# 7. At least 11 (default value, can be changed in xml) items are present in pool 3.
#
################################################################

CONSTANTS_FILE="constants.sh"
arch=$(uname -i)

InstallLsof() {
    case $DISTRO in
        redhat* | centos* | fedora*)
            yum install lsof -y
            ;;
        ubuntu* | debian*)
            apt update; apt install -y lsof
            ;;
        suse* )
            zypper install -y lsof
                ;;
        *)
            msg="ERROR: Distro '$DISTRO' not supported"
            LogMsg "${msg}"
            UpdateSummary "${msg}"
            SetTestStateAborted
            exit 1
            ;;
    esac

    if [ $? -ne 0 ]; then
        LogMsg "ERROR: Failed to install lsof"
        UpdateSummary "ERROR: Failed to install lsof"
        SetTestStateAborted
        exit 1
    fi
}

dos2unix utils.sh
# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

#
# Source constants file and initialize most common variables
#
UtilsInit

#
# Delete any summary.log files from a previous run
#
rm -f ~/summary.log
touch ~/summary.log

#
# Source the constants.sh file to pickup definitions
# from the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    msg="Error: no ${CONSTANTS_FILE} file"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateAborted
    exit 1
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${kvp_pool:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter kvp_pool number is not defined in ${CONSTANTS_FILE}"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateAborted
    exit 1
fi

if [ "${kvp_items:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter kvp_items is not defined in ${CONSTANTS_FILE}"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateAborted
    exit 1
fi

#
# 1. verify that the KVP Daemon is running
#
pid=`pgrep "hypervkvpd|hv_kvp_daemon"`
if [ $? -ne 0 ]; then
    LogMsg "KVP Daemon is not running by default"
    UpdateSummary "KVP daemon not running by default, basic test: Failed"
    SetTestStateFailed
    exit 1
fi
LogMsg "KVP Daemon is running"
UpdateSummary "KVP Daemon is running"

#
# 2. run the KVP client tool and verify that the data pools are created and accessible
#
if [[ ${arch} == 'x86_64' ]]; then
    kvp_client="kvp_client64"
elif [[ ${arch} == 'i686' ]]; then
    kvp_client="kvp_client32"
else
    LogMsg "Error: Unable to detect OS architecture!"
    SetTestStateAborted
    exit 1
fi

#
# Make sure we have the kvp_client tool
#
if [ ! -e ~/${kvp_client} ]; then
    msg="Error: ${kvp_client} tool is not on the system"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateAborted
    exit 1
fi

chmod +x /root/kvp_client*
poolCount=`/root/$kvp_client | grep -i pool | wc -l`
if [ $poolCount -ne 5 ]; then
    msg="Error: Could not find a total of 5 KVP data pools"
    LogMsg $msg
    UpdateSummary $msg
    SetTestStateFailed
    exit 1
fi
LogMsg "Verified that all 5 KVP data pools are listed properly"
UpdateSummary "Verified that all 5 KVP data pools are listed properly"

#
# 3. check kvp_pool file permission is 644
#
permCount=`stat -c %a /var/lib/hyperv/.kvp_pool* | grep 644 | wc -l`
if [ $permCount -ne 5 ]; then
    LogMsg ".kvp_pool file permission is incorrect "
    UpdateSummary ".kvp_pool file permission is incorrect"
    SetTestStateFailed
    exit 1
fi
LogMsg "Verified that .kvp_pool files permission is 644"
UpdateSummary "Verified that .kvp_pool files permission is 644"

#
# 4. check kernel version supports hv_kvp
#
CheckVMFeatureSupportStatus "3.10.0-514"
if [ $? -eq 0 ]; then
    ls -la /proc/$pid/fd | grep /dev/vmbus/hv_kvp
    if [ $? -ne 0 ]; then
        LogMsg "ERROR: there is no hv_kvp in the /proc/$pid/fd "
        UpdateSummary "ERROR: there is no hv_kvp in the /proc/$pid/fd"
        SetTestStateFailed
        exit 1
    fi
else
    LogMsg "This kernel version does not support /dev/vmbus/hv_kvp, skip this step"
fi

#
# 5. check lsof number for kvp whether increase or not after sleep 2 minutes
#
GetDistro
command -v lsof > /dev/null
if [ $? -ne 0 ]; then
    InstallLsof
fi

lsofCountBegin=`lsof | grep -c kvp`
sleep 120
lsofCountEnd=`lsof | grep -c kvp`
if [ $lsofCountBegin -ne $lsofCountEnd ]; then
    msg="ERROR: hypervkvp opened file number has changed from $lsofCountBegin to $lsofCountEnd"
    LogMsg "${msg}"
    UpdateSummary "${msg}"
    SetTestStateFailed
    exit 1
fi
LogMsg "Verified that lsof for kvp is $lsofCountBegin, after 2 minutes is $lsofCountEnd"
UpdateSummary "Verified that lsof for kvp is $lsofCountBegin, after 2 minutes is $lsofCountEnd"

#
# 6. Check if KVP pool 3 file has a size greater than zero
#
poolFileSize=$(ls -l /var/lib/hyperv/.kvp_pool_${kvp_pool} | awk '{print $5}')
if [ $poolFileSize -eq 0 ]; then
    msg="Error: the kvp_pool_${kvp_pool} file size is zero"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateFailed
    exit 1
fi

#
# 7. Check the number of records in Pool 3.
# Below 11 entries (default value) the test will fail
#
pool_records=$(~/${kvp_client} $kvp_pool | wc -l)
if [ $pool_records -eq 0 ]; then
    msg="Error: Could not list the KVP Items in pool ${kvp_pool}"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateFailed
    exit 1
fi
LogMsg "KVP items in pool ${kvp_pool}: ${pool_records}"
UpdateSummary "KVP items in pool ${kvp_pool}: ${pool_records}"

poolItemNumber=$(~/${kvp_client} $kvp_pool | awk 'FNR==2 {print $4}')
if [ $poolItemNumber -lt $kvp_items ]; then
    msg="Error: Pool $kvp_pool has only $poolItemNumber items. We need $kvp_items items or more"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateFailed
    exit 1
fi

actualPoolItemNumber=$(~/${kvp_client} $kvp_pool | grep Key | wc -l)
if [ $poolItemNumber -ne $actualPoolItemNumber ]; then
    msg="Error: Pool $kvp_pool reported $poolItemNumber items but actually has $actualPoolItemNumber items"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    SetTestStateFailed
    exit 1
fi

SetTestStateCompleted
exit 0
