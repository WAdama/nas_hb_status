#!/bin/bash
# Version 3.0.0
set -euo pipefail
IFS=$'\n\t'
#Functions
readlog() {
    [[ -e "$1" ]] || return
    if [[ $1 == *.xz ]]; then
        xz -dc "$1"
    else
        cat "$1"
    fi
}
get_backup_status() {
    local result="$1"
    case "$result" in
        *"partially completed"*) echo 10 ;;
        *"resume backup"*) echo 9 ;;
        *"suspension complete"*) echo 8 ;;
        *"cancelled"*) echo 7 ;;
        *"started"*) echo 6 ;;
        *"created"*) echo 5 ;;
        *"Failed"*) echo 4 ;;
        *"finished successfully"*) echo 1 ;;
        *) echo 0 ;;
    esac
}
get_rotation_status() {
    local result="$1"
    case "$result" in
        "version_deleting") echo 3 ;;
        "preparing_version_delete") echo 2 ;;
        *) echo 1 ;;
    esac
}
get_integrity_status() {
    local result="$1"
    case "$result" in
        *"Failed to run backup integrity check"*) echo 4 ;;
        *"target is found broken"*) echo 3 ;;
        *"has started"*) echo 2 ;;
        *"No error was found"*) echo 1 ;;
        *) echo 0 ;;
    esac
}
timestamp() {
    local dt="$1"
    if [ -z "$dt" ]; then
        echo 0
    else
        date -d "$dt" +%s
    fi
}
calculate_runtime() {
    local start="$1"
    local end="$2"
    echo $(( end - start ))
}
#Load configuration file
mapfile -t BKP_TASKS < <( jq -r .tasks[] "$1" )
if [ $? == 1 ]
then
    echo "Configuration file missing... Please provide a configuration file to run this script!"
    exit
fi
#Getting Hyper Backup version and set proper log file
VERSION=$(/usr/syno/bin/synopkg version HyperBackup)
VERSION=${VERSION:0:1}${VERSION:2:1}${VERSION:4:1}
if [ "$VERSION" -gt "400" ]
then
    mapfile -t SYSLOG < <( ls -1r /var/packages/HyperBackup/var/log/hyperbackup.log* )
else
    SYSLOG=("/var/log/messages")
fi
if [ "$VERSION" -gt "411" ]
then
    mapfile -t LOGS < <( ls -1r /var/packages/HyperBackup/var/log/synolog/synobackup.log* )
else
    mapfile -t LOGS < <( ls -1r /var/log/synolog/synobackup.log* )
fi
TASKS=$(synowebapi -s --exec api=SYNO.Backup.Task method=list version=1)
#Getting actual time
TIME=$(date +%s)
#Creating sensor
echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for BKP_TASK in "${BKP_TASKS[@]}"
do
    BKP_STATUS=0
    BKP_STATUS_INT=0
    #Getting and setting backup status data
    BKP_RESULT=$(for f in "${LOGS[@]}"; do
        readlog "$f"
    done | awk '(/Backup task/ || /backup task/) && /\['"$BKP_TASK"'\]/ { line=$0 } END { print line }')
    BKP_ROTATE=$( (jq -r '.data.task_list[] | select(.name=="'"$BKP_TASK"'")' | jq -r .status) <<< "$TASKS")
    BKP_RESULT_INT=$(for f in "${LOGS[@]}"; do
        readlog "$f"
    done | awk '/integrity check/ && /\['"$BKP_TASK"'\]/ { line=$0 } END { print line }')
    BKP_TASKID=$(for f in "${SYSLOG[@]}"; do
        readlog "$f"
    done | awk '/Backup task/ && /\['"$BKP_TASK"'\]/ { line=$0 } END { print line }' | awk -F'[][]' '{print $2}')
    BKP_STATUS=$(get_backup_status "$BKP_RESULT")
    BKP_STATUS_INT=$(get_integrity_status "$BKP_RESULT_INT")
    if [ "$BKP_STATUS" == 1 ]; then
        BKP_STATUS=$(get_rotation_status "$BKP_ROTATE")
    fi
    #Getting and calculating backup sizes and times (only when at least one backup task has been completed)
    if [ -z "${BKP_TASKID}" ]; then
        BKP_SIZE=0
        BKP_SIZE_LAST=0
        BKP_CHANGE=0
        BKP_RUNTIME=0
        BKP_TIME_STRT=0
        BKP_TIME_END=0
        BKP_LAST_RUN=0
        BKP_RUNTIME_INT=0
        BKP_TIME_INT_STRT=0
        BKP_TIME_INT_END=0
        BKP_LAST_RUN_INT=0
        BKP_SPEED=0
    else
        BKP_SIZE=$(($(for f in "${SYSLOG[@]}"; do
           readlog "$f"
       done | awk "/img_backup/ && /$BKP_TASKID/ && /TargetSize/" | tail -1 | sed -n "s/^.*: TargetSize(KB):\[\s*\([0-9]*\).*$/\1/p")*1024))
        BKP_SIZE_LAST=$(($(for f in "${SYSLOG[@]}"; do
           readlog "$f"
        done | awk "/img_backup/ && /$BKP_TASKID/ && /TargetSize/" | tail -1 | sed -n "s/^.*LastBackupTargetSize(KB):\[\s*\([0-9]*\).*$/\1/p")*1024))
        BKP_CHANGE=$(("$BKP_SIZE"-"$BKP_SIZE_LAST"))
        BKP_RUNTIME=$(for f in "${SYSLOG[@]}"; do
            readlog "$f"
        done | awk "/Backup task/ && /\[$BKP_TASK\]/" | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p")
        BKP_TIME_STRT=$(timestamp "$(for f in "${LOGS[@]}"; do
            readlog "$f"
        done | awk "/Backup task/ && /started/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
         BKP_TIME_RESD=$(timestamp "$(for f in "${LOGS[@]}"; do
             readlog "$f"
        done | awk "/backup task/ && /resume/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
        if [ -n "${BKP_TIME_RESD}" ] && [ "${BKP_STATUS}" == 7 ]; then
            BKP_TIME_STRT="$BKP_TIME_RESD"
        fi
        BKP_TIME_END=$(timestamp "$(for f in "${LOGS[@]}"; do
            readlog "$f"
       done | awk "/Backup task/ && /finished/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
        BKP_TIME_INT_STRT=$(timestamp "$(for f in "${LOGS[@]}"; do
           readlog "$f"
       done | awk "/Backup integrity check/ && /started/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
        BKP_TIME_INT_END=$(timestamp "$(for f in "${LOGS[@]}"; do
            readlog "$f"
       done | awk "/Backup integrity check/ && /finished/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
        if [ "$BKP_STATUS_INT" == 2 ]; then
            BKP_TIME_INT_END="0"
            BKP_LAST_RUN_INT="0"
            BKP_RUNTIME_INT="0"
        else
            BKP_LAST_RUN_INT=$(calculate_runtime "$BKP_TIME_INT_END" "$TIME")
            BKP_RUNTIME_INT=$(calculate_runtime "$BKP_TIME_INT_STRT" "$BKP_TIME_INT_END")
        fi
        BKP_LAST_RUN=$(("$TIME"-"$BKP_TIME_END"))
        if [ "$BKP_TIME_END" != 0 ]; then
            BKP_REAL_STRT=$(timestamp "$(for f in "${SYSLOG[@]}"; do
               readlog "$f"
           done | awk "/\[BkpCtrl\]/ && /\[$BKP_TASKID\]/" | tail -1 | awk '{print $1}')")
            BKP_REAL_END=$(timestamp "$(for f in "${SYSLOG[@]}"; do
               readlog "$f"
           done | awk "/\[BackupTaskFinished\]/ && /\[$BKP_TASKID\]/" | tail -1 | awk '{print $1}')")
            BKP_REALRUNTIME=$(("$BKP_REAL_END"-"$BKP_REAL_STRT"))
            if [ "$BKP_STATUS" == 1 ] || [ "$BKP_STATUS" == 8 ]; then
                BKP_SPEED=$(("$BKP_CHANGE"/"$BKP_REALRUNTIME"))
            else
                BKP_SPEED="0"
            fi
        fi
    fi
    if [ "$BKP_STATUS" == 4 ] || [ "$BKP_STATUS" == 7 ]; then
        BKP_RUNTIME=$(calculate_runtime "$BKP_TIME_STRT" "$TIME")
        BKP_LAST_RUN=$(calculate_runtime "$BKP_TIME_STRT" "$TIME")
    fi
    if [ "$BKP_STATUS_INT" == 2 ]; then
        BKP_RUNTIME_INT=$(("$TIME"-"$BKP_TIME_INT_STRT"))
        BKP_LAST_RUN_INT=$(("$TIME"-"$BKP_TIME_INT_STRT"))
    fi
    echo "<result><channel>$BKP_TASK: Last backup</channel><value>$BKP_LAST_RUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>
    <result><channel>$BKP_TASK: Status</channel><value>$BKP_STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result>
    <result><channel>$BKP_TASK: Backup Runtime</channel><value>$BKP_RUNTIME</value><unit>TimeSeconds</unit></result>
    <result><channel>$BKP_TASK: Size</channel><value>$BKP_SIZE</value><unit>BytesDisk</unit><VolumeSize>GigaByte</VolumeSize></result>
    <result><channel>$BKP_TASK: Change</channel><value>$BKP_CHANGE</value><unit>BytesDisk</unit><VolumeSize>GigaByte</VolumeSize></result>
    <result><channel>$BKP_TASK: Speed</channel><value>$BKP_SPEED</value><unit>SpeedDisk</unit><SpeedSize>MegaByte</SpeedSize></result>
    <result><channel>$BKP_TASK: Integrity Check</channel><value>$BKP_STATUS_INT</value><ValueLookup>prtg.standardlookups.nas.hbintstatus</ValueLookup><ShowChart>0</ShowChart></result>
    <result><channel>$BKP_TASK: Last Integrity Check</channel><value>$BKP_LAST_RUN_INT</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>608400</LimitMaxWarning><LimitMaxError>694800</LimitMaxError></result>
    <result><channel>$BKP_TASK: Integrity Check Runtime</channel><value>$BKP_RUNTIME_INT</value><unit>TimeSeconds</unit></result>"
done
echo "</prtg>"
exit
