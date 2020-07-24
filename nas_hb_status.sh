#!/bin/bash
# Version 1.2.2

CONF=$1
source $CONF

LOG="/var/log/synolog/synobackup.log"
LOGROTATED="/var/log/synolog/synobackup.log.0"
SYSLOG="/var/log/messages"

echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for TASK in "${TASKS[@]}"
do
CONTENT=`cat $LOG | grep "task" | grep "\[$TASK\]" | tail -1`
if [ -z "${CONTENT}" ]; then
	CONTENT=`cat $LOGROTATED | grep "task" | grep "\[$TASK\]" | tail -1`
fi
INTEGRITY=`cat $LOG | grep "Backup integrity check" | grep "\[$TASK\]" | tail -1`
if [ -z "${INTEGRITY}" ]; then
	INTEGRITY=`cat $LOGROTATED | grep "Backup integrity check" | grep "\[$TASK\]" | tail -1`
fi
TASKID=`cat $SYSLOG | grep "task" | grep "\[$TASK\]" | tail -1 | sed -n "s/^.*img_backup: (\s*\([0-9]*\).*$/\1/p"`
if [ -z "${TASKID}" ]; then
	RUNTIME="0"
	BKPSIZE="0"
	LASTBKPSIZE="0"
	else
	RUNTIME=`cat $SYSLOG | grep "task" | grep "\[$TASK\]" | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p"`
	BKPSIZE=`cat $SYSLOG | grep "img_backup" | grep "$TASKID" | grep "Storage Statistics" | tail -1 | sed -n "s/^.*: TargetSize(KB):\[\s*\([0-9]*\).*$/\1/p"`
	LASTBKPSIZE=`cat $SYSLOG | grep "img_backup" | grep "$TASKID" | grep "Storage Statistics" | tail -1 | sed -n "s/^.*LastBackupTargetSize(KB):\[\s*\([0-9]*\).*$/\1/p"`
fi
TIME=`cat $LOG | grep "task" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`
if [ -z "${TIME}" ]; then
	TIME=`cat $LOGROTATED | grep "task" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`
fi
INTTIME=`cat $LOG | grep "Backup integrity check" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`
if [ -z "${INTTIME}" ]; then
	INTTIME=`cat $LOGROTATED | grep "Backup integrity check" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`

fi
TIMEEND=`date -d"$TIME" +%s`
INTTIMEEND=`date -d"$INTTIME" +%s`

if [[ $CONTENT == *"finished successfully"* ]]; then
	STATUS="1"
	elif [[ $CONTENT == *"Failed"* ]]; then
	STATUS="2"
	elif [[ $CONTENT == *"created"* ]]; then
	STATUS="3"
	elif [[ $CONTENT == *"started"* ]]; then
	STATUS="4"
	elif [[ $CONTENT == *"cancelled"* ]]; then
	STATUS="5"
	elif [[ $CONTENT == *"suspension complete"* ]]; then
	STATUS="6"
	elif [[ $CONTENT == *"resume backup"* ]]; then
	STATUS="7"
fi

if [[ $INTEGRITY == *"No error was found"* ]]; then
	INTSTATUS="1"
	elif [[ $INTEGRITY == *"has started"* ]]; then
	INTSTATUS="2"
	elif [[ $INTEGRITY == *"target is found broken"* ]]; then
	INTSTATUS="3"
	else
	INTSTATUS="0"
fi

ACTTIME=`date +%s`
LASTRUN=$(($ACTTIME - $TIMEEND))
INTLASTRUN=$(($ACTTIME - $INTTIMEEND))

BKPCHANGE=$(($BKPSIZE - $LASTBKPSIZE))

echo "<result><channel>$TASK: Last backup</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>$TASK: Status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$TASK: Runtime</channel><value>$RUNTIME</value><unit>TimeSeconds</unit></result><result><channel>$TASK: Size</channel><value>$(($BKPSIZE * 1024))</value><unit>BytesDisk</unit></result><result><channel>$TASK: Change</channel><value>$(($BKPCHANGE * 1024))</value><unit>BytesDisk</unit></result><result><channel>$TASK: Integrity Check</channel><value>$INTSTATUS</value><ValueLookup>prtg.standardlookups.nas.hbintstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$TASK: Last integrity check</channel><value>$INTLASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>608400</LimitMaxWarning><LimitMaxError>694800</LimitMaxError></result>"
done
echo "</prtg>"
exit
