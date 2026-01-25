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
#Getting results for one task
for BKP_TASK in "${BKP_TASKS[@]}"
do
    #Getting backup status data
    BKP_STATUS=0
    BKP_STATUS_INT=0
    #Getting and setting backup status data
    BKP_RESULT=$(for f in "${LOGS[@]}"; do
        readlog "$f"
    done | awk '(/Backup task/ || /backup task/) && /\['"$BKP_TASK"'\]/ { line=$0 } END { print line }')
    BKP_ROTATE=$( (jq -r '.data.task_list[] | select(.name=="'"$BKP_TASK"'")' | jq -r .status) <<< "$TASKS")
    BKP_TASKID=$(for f in "${SYSLOG[@]}"; do
        readlog "$f"
    done | awk '/Backup task/ && /\['"$BKP_TASK"'\]/ { line=$0 } END { print line }' | awk -F'[][]' '{print $2}')
    #Setting value for status of last backup
    BKP_STATUS=$(get_backup_status "$BKP_RESULT")
    if [ "$BKP_STATUS" == 1 ]; then
        BKP_STATUS=$(get_rotation_status "$BKP_ROTATE")
    fi
    #Getting and calculating backup times (only when at least one backup task has been completed)
    if [ -z "${BKP_TASKID}" ]; then
        BKP_RUNTIME="0"
        BKP_TIME_STRT="0"
        BKP_TIME_END="0"
        BKP_LAST_RUN="0"
    else
        #Getting and calculating times
        BKP_RUNTIME=$(for f in "${SYSLOG[@]}"; do
            readlog "$f"
        done | awk "/Backup task/ && /\[$BKP_TASK\]/" | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p")
        BKP_TIME_STRT=$(timestamp "$(for f in "${LOGS[@]}"; do
            readlog "$f"
        done | awk "/Backup task/ && /started/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
        if [ -z "${BKP_TIME_STRT}" ]; then
            BKP_TIME_STRT="0"
        fi
         BKP_TIME_RESD=$(timestamp "$(for f in "${LOGS[@]}"; do
             readlog "$f"
        done | awk "/backup task/ && /resume/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
        if [ -n "${BKP_TIME_RESD}" ] && [ "${BKP_STATUS}" == 7 ]; then
            BKP_TIME_STRT="$BKP_TIME_RESD"
        fi
        BKP_TIME_END=$(timestamp "$(for f in "${LOGS[@]}"; do
            readlog "$f"
       done | awk "/Backup task/ && /finished/ && /\[$BKP_TASK\]/" | tail -1 | awk -F "\t" '{print $2}')")
        if [ -z "${BKP_TIME_END}" ]; then
            BKP_TIME_END="0"
        fi
        BKP_LAST_RUN=$(calculate_runtime "$BKP_TIME_END" "$TIME")
    fi
    #Setting times when backups are running
    if [ "$BKP_STATUS" == 4 ] || [ "$BKP_STATUS" == 7 ]; then
        BKP_RUNTIME=$(calculate_runtime "$BKP_TIME_STRT" "$TIME")
        BKP_LAST_RUN=$(calculate_runtime "$BKP_TIME_STRT" "$TIME")
    fi
    if [ "$BKP_TIME_END" == 0 ]; then
        BKP_LAST_RUN="0"
    fi
    #Creating sensor
    echo "<result><channel>$BKP_TASK: Last backup</channel><value>$BKP_LAST_RUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>
    <result><channel>$BKP_TASK: Status</channel><value>$BKP_STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result>
    <result><channel>$BKP_TASK: Backup Runtime</channel><value>$BKP_RUNTIME</value><unit>TimeSeconds</unit></result>"
done
echo "</prtg>"
exit
