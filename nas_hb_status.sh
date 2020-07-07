#!/bin/bash
# Version 1.1.0

CONF=$1
source $CONF

LOG="/var/log/synolog/synobackup.log"
SYSLOG="/var/log/messages"

echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for TASK in "${TASKS[@]}"
do

CONTENT=`cat $LOG | grep "task" | grep "\[$TASK\]" | tail -1`
TASKID=`cat $SYSLOG | grep "task" | grep "\[$TASK\]" | tail -1 | sed -n "s/^.*img_backup: (\s*\([0-9]*\).*$/\1/p"`
RUNTIME=`cat $SYSLOG | grep "task" | grep "\[$TASK\]" | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p"`
BKPSIZE=`cat $SYSLOG | grep "img_backup" | grep "$TASKID" | grep "Storage Statistics" | tail -1 | sed -n "s/^.*: TargetSize(KB):\[\s*\([0-9]*\).*$/\1/p"`
LASTBKPSIZE=`cat $SYSLOG | grep "img_backup" | grep "$TASKID" | grep "Storage Statistics" | tail -1 | sed -n "s/^.*LastBackupTargetSize(KB):\[\s*\([0-9]*\).*$/\1/p"`
TIME=`cat $LOG | grep "task" | grep "\[$TASK\]" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}" | tail -1`

TIMEEND=`date -d"$TIME" +%s`

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

ACTTIME=`date +%s`
LASTRUN=$(($ACTTIME - $TIMEEND))

BKPCHANGE=$(($BKPSIZE - $LASTBKPSIZE))

echo "<result><channel>$TASK: Time passed</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>$TASK: Status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$TASK: Runtime</channel><value>$RUNTIME</value><unit>TimeSeconds</unit></result><result><channel>$TASK: Size</channel><value>$(($BKPSIZE * 1024))</value><unit>BytesDisk</unit></result><result><channel>$TASK: Change</channel><value>$(($BKPCHANGE * 1024))</value><unit>BytesDisk</unit></result>"
done
echo "</prtg>"
exit
