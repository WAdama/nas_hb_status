#!/bin/bash
# Version 1.0.4

#Load configuration file
mapfile -t BKP_TASKS < <( jq -r .tasks[] "$1" )
if [ $? == 1 ]
then
    echo "Configuration missing... Please provide a configuration file to run this script!"
    exit
fi
#Getting Hyper Backup version and set proper log file
VERSION=$(/usr/syno/bin/synopkg version HyperBackup)
VERSION=${VERSION:0:1}${VERSION:2:1}${VERSION:4:1}
if [ "$VERSION" -gt "400" ]
then
    mapfile -t SYSLOG < <( find /var/packages/HyperBackup/var/log/hyperbackup.l*[!.xz] | sort -r )
    if find /var/packages/HyperBackup/var/log/hyperbackup.*.xz > /dev/null 2>&1
    then
        MESSAGE="Compression for log file active. This may obstruct the sensor data!"
    fi
else
    SYSLOG=("/var/log/messages")
fi
if [ "$VERSION" -gt "411" ]
then
    mapfile -t LOGS < <( find /var/packages/HyperBackup/var/log/synolog/synobackup.l*[!.xz] | sort -r )
else
    mapfile -t LOGS < <( find /var/log/synolog/synobackup.l*[!.xz] | sort -r )
fi
TIME=$(date +%s)

echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
#Getting results for one task
for BKP_TASK in "${BKP_TASKS[@]}"
do
    #Getting backup status data
    BKP_RESULT=$(awk "(/Backup task/ || /backup task/ || /Restore/ || /restore/) && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1)
    BKP_TASKID=$(awk "/Backup task/ && /\[$BKP_TASK\]/" "${SYSLOG[@]}" | tail -1 | sed -n "s/^.*: (\s*\([0-9]*\).*$/\1/p")
    #Setting value for status of last backup
    case $BKP_RESULT in
        *"Failed to run restore"*) BKP_STATUS="15" ;;
        *"Restore finished successfully"*) BKP_STATUS="14" ;;
        *"Started to restore"*) BKP_STATUS="13" ;;
        *"Relink finished successfully"*) BKP_STATUS="12" ;;
        *"Relink task started"*) BKP_STATUS="11" ;;
        *"discarded successfully"*) BKP_STATUS="10" ;;
        *"discard backup"*) BKP_STATUS="9" ;;
        *"partially completed"*) BKP_STATUS="8" ;;
        *"resume backup"*) BKP_STATUS="7" ;;
        *"suspension complete"*) BKP_STATUS="6" ;;
        *"cancelled"*) BKP_STATUS="5" ;;
        *"started"*) BKP_STATUS="4" ;;
        *"created"*) BKP_STATUS="3" ;;
        *"Failed"*) BKP_STATUS="2" ;;
        *"finished successfully"*) BKP_STATUS="1" ;;
        *) BKP_STATUS="0" ;;
    esac
    #Getting and calculating backup times (only when at least one backup task has been completed)
    if [ -z "${BKP_TASKID}" ]; then
        BKP_RUNTIME="0"
        BKP_TIME_STRT="0"
        BKP_TIME_END="0"
        BKP_LAST_RUN="0"
    else
        #Getting and calculating times
        BKP_RUNTIME=$(awk "/Backup task/ && /\[$BKP_TASK\]/" "${SYSLOG[@]}" | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p")
        BKP_TIME_STRT=$(date -d "$(awk "/Backup task/ && /started/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | awk -F "\t" '{print $2}')" +%s)
        if [ -z "${BKP_TIME_STRT}" ]; then
            BKP_TIME_STRT="0"
        fi
        BKP_TIME_RESD=$(date -d "$(awk "/backup task/ && /resume/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | awk -F "\t" '{print $2}')" +%s)
        if [ -n "${BKP_TIME_RESD}" ] && [ "${BKP_STATUS}" == 7 ]; then
            BKP_TIME_STRT="$BKP_TIME_RESD"
        fi
        BKP_TIME_END=$(date -d "$(awk "/Backup task/ && /finished/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | awk -F "\t" '{print $2}')" +%s)
        if [ -z "${BKP_TIME_END}" ]; then
            BKP_TIME_END="0"
        fi
        BKP_LAST_RUN=$(("$TIME"-"$BKP_TIME_END"))
    fi
    #Setting times when backups are running
    if [ "$BKP_STATUS" == 4 ] || [ "$BKP_STATUS" == 7 ]; then
        BKP_TIME_STRT=$(date -d "$(awk "/Backup task/ && /started/ && /\[$BKP_TASK\]/" "${LOGS[@]}" | tail -1 | awk -F "\t" '{print $2}')" +%s)
        BKP_RUNTIME=$(("$TIME"-"$BKP_TIME_STRT"))
        BKP_LAST_RUN=$(("$TIME"-"$BKP_TIME_END"))
    fi
    if [ "$BKP_TIME_END" == 0 ]; then
        BKP_LAST_RUN="0"
    fi
    #Creating sensor
    echo "<result><channel>$BKP_TASK: Last backup</channel><value>$BKP_LAST_RUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>$BKP_TASK: Status</channel><value>$BKP_STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$BKP_TASK: Backup Runtime</channel><value>$BKP_RUNTIME</value><unit>TimeSeconds</unit></result>"
done
if [ "${MESSAGE}" ]; then
    echo "<text>$MESSAGE</text>"
fi
echo "</prtg>"
exit
