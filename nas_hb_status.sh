#!/bin/bash
# Version 2.1.1

#Load configuration file
source "$1"
#Getting Hyper Backup version and set proper log file
VERSIONHB=$(/usr/syno/bin/synopkg version HyperBackup)
VERSION=${VERSIONHB:0:1}${VERSIONHB:2:1}
if [ "$VERSION" -gt "40" ]
then
    mapfile -t SYSLOG < <( ls -1r /volume1/@appdata/HyperBackup/log/hyperbackup.l*[!.xz] | tail -2 )
else
    SYSLOG=("/var/log/messages")
fi
mapfile -t LOGS < <( ls -1r /var/log/synolog/synobackup.l*[!.xz] )
TIME=$(date +%s)

echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
#Getting results for task
for BKP_TASK in "${BKP_TASKS[@]}"
do
    #Getting backup status data
    BKP_RESULT=$(awk "/task/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1)
    BKP_RESULT_INT=$(awk "/integrity check/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1)
    BKP_TASKID=$(awk "/task/ && /\[$BKP_TASK\]/" "${SYSLOG[@]}" | tail -1 | sed -n "s/^.*: (\s*\([0-9]*\).*$/\1/p")
    #Setting value for status of last backup
    case $BKP_RESULT in
        *"finished successfully"*) BKP_STATUS="1" ;;
        *"Failed"*) BKP_STATUS="2" ;;
        *"created"*) BKP_STATUS="3" ;;
        *"started"*) BKP_STATUS="4" ;;
        *"cancelled"*) BKP_STATUS="5" ;;
        *"suspension complete"*) BKP_STATUS="6" ;;
        *"resume backup"*) BKP_STATUS="7" ;;
        *"partially completed"*) BKP_STATUS="8" ;;
        *"discard backup"*) BKP_STATUS="9" ;;
        *"discarded successfully"*) BKP_STATUS="10" ;;
        *) BKP_STATUS="0" ;;
    esac
    #Setting value for status of last integrity check
    case $BKP_RESULT_INT in
        *"No error was found"*) BKP_STATUS_INT="1" ;;
        *"has started"*) BKP_STATUS_INT="2" ;;
        *"target is found broken"*) BKP_STATUS_INT="3" ;;
        *"Failed to run backup integrity check"*) BKP_STATUS_INT="4" ;;
        *) BKP_STATUS_INT="0" ;;
    esac
    #Getting and calculating backup sizes and times
    if [ -z "${BKP_TASKID}" ]; then
        BKP_SIZE="0"
        BKP_SIZE_LAST="0"
        BKP_CHANGE="0"
        BKP_RUNTIME="0"
        BKP_TIME_STRT="0"
        BKP_TIME_END="0"
        BKP_LAST_RUN="0"
        BKP_RUNTIME_INT="0"
        BKP_TIME_INT_STRT="0"
        BKP_TIME_INT_END="0"
        BKP_LAST_RUN_INT="0"
    else
        BKP_SIZE=$(("$(awk "/img_backup/ && /$BKP_TASKID/ && /TargetSize/" "${SYSLOG[@]}" | tail -1 | sed -n "s/^.*: TargetSize(KB):\[\s*\([0-9]*\).*$/\1/p")"*1024))
        BKP_SIZE_LAST=$(("$(awk "/img_backup/ && /$BKP_TASKID/ && /TargetSize/" "${SYSLOG[@]}" | tail -1 | sed -n "s/^.*LastBackupTargetSize(KB):\[\s*\([0-9]*\).*$/\1/p")"*1024))
        BKP_CHANGE=$(("$BKP_SIZE"-"$BKP_SIZE_LAST"))
        #Getting and calculating times
        BKP_RUNTIME=$(awk "/Backup task/ && /\[$BKP_TASK\]/" "${SYSLOG[@]}" | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p")
        BKP_TIME_STRT=$(awk "/Backup task/ && /started/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
        if [ -z "${BKP_TIME_STRT}" ]; then
            BKP_TIME_STRT="0"
        else
            BKP_TIME_STRT=$(date -d "$BKP_TIME_STRT" +%s)
        fi
        BKP_TIME_RESD=$(awk "/backup task/ && /resume/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
        if [ -n "${BKP_TIME_RESD}" ] && [ "${BKP_STATUS}" == 7 ]; then
            BKP_TIME_STRT=$(date -d "$BKP_TIME_RESD" +%s)
        fi
        BKP_TIME_END=$(awk "/Backup task/ && /finished/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
        if [ -z "${BKP_TIME_END}" ]; then
            BKP_TIME_END="0"
        else
            BKP_TIME_END=$(date -d "$BKP_TIME_END" +%s)
        fi
        BKP_TIME_INT_STRT=$(awk "/Backup integrity check/ && /started/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
        if [ -z "${BKP_TIME_INT_STRT}" ]; then
            BKP_TIME_INT_STRT="0"
        else
            BKP_TIME_INT_STRT=$(date -d "$BKP_TIME_INT_STRT" +%s)
        fi
        BKP_TIME_INT_END=$(awk "/Backup integrity check/ && /finished/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
        if [ -z "${BKP_TIME_INT_END}" ]; then
            BKP_TIME_INT_END="0"
            BKP_LAST_RUN_INT="0"
        else
            BKP_TIME_INT_END=$(date -d "$BKP_TIME_INT_END" +%s)
            BKP_LAST_RUN_INT=$(("$TIME"-"$BKP_TIME_INT_END"))
        fi
        BKP_LAST_RUN=$(("$TIME"-"$BKP_TIME_END"))
        BKP_RUNTIME_INT=$(("$BKP_TIME_INT_END"-"$BKP_TIME_INT_STRT"))
        if [ "$BKP_TIME_END" != 0 ]; then
            BKP_REAL_STRT=$(date -d "$(awk "/\[BkpCtrl\]/ && /\[$BKP_TASKID\]/" "${SYSLOG[@]}" | tail -1 | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")" +%s)
            BKP_REAL_END=$(date -d "$(awk "/\[BackupTaskFinished\]/ && /\[$BKP_TASKID\]/" "${SYSLOG[@]}" | tail -1 | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")" +%s)
            BKP_REALRUNTIME=$(("$BKP_REAL_END"-"$BKP_REAL_STRT"))
            BKP_SPEED=$(("$BKP_CHANGE"/"$BKP_REALRUNTIME"))
        fi
    fi
    #Setting times when backup is running
    if [ "$BKP_STATUS" == 4 ] || [ "$BKP_STATUS" == 7 ]; then
        BKP_RUNTIME=$(("$TIME"-"$BKP_TIME_STRT"))
        BKP_LAST_RUN=$(("$TIME"-"$BKP_TIME_END"))
    fi
    if [ "$BKP_TIME_END" == 0 ]; then
        BKP_LAST_RUN="0"
    fi
    if [ "$BKP_STATUS_INT" == 2 ]; then
        BKP_RUNTIME_INT=$(("$TIME"-"$BKP_TIME_INT_STRT"))
        BKP_LAST_RUN_INT=$(("$TIME"-"$BKP_TIME_INT_END"))
    fi
    if [ "$BKP_TIME_INT_END" == 0 ]; then
        BKP_LAST_RUN_INT="0"
    fi
    #Creating sensor
    echo "<result><channel>$BKP_TASK: Last backup</channel><value>$BKP_LAST_RUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>$BKP_TASK: Status</channel><value>$BKP_STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$BKP_TASK: Backup Runtime</channel><value>$BKP_RUNTIME</value><unit>TimeSeconds</unit></result><result><channel>$BKP_TASK: Size</channel><value>$BKP_SIZE</value><unit>BytesDisk</unit><VolumeSize>GigaByte</VolumeSize></result><result><channel>$BKP_TASK: Change</channel><value>$BKP_CHANGE</value><unit>BytesDisk</unit><VolumeSize>GigaByte</VolumeSize></result><result><channel>$BKP_TASK: Speed</channel><value>$BKP_SPEED</value><unit>SpeedDisk</unit><SpeedSize>MegaByte</SpeedSize></result><result><channel>$BKP_TASK: Integrity Check</channel><value>$BKP_STATUS_INT</value><ValueLookup>prtg.standardlookups.nas.hbintstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$BKP_TASK: Last Integrity Check</channel><value>$BKP_LAST_RUN_INT</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>608400</LimitMaxWarning><LimitMaxError>694800</LimitMaxError></result><result><channel>$BKP_TASK: Integrity Check Runtime</channel><value>$BKP_RUNTIME_INT</value><unit>TimeSeconds</unit></result>"
done
echo "</prtg>"
exit
