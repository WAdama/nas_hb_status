#!/bin/bash
# Version 1.0.0

CONF=$1
source $CONF

LOG="/var/log/synolog/synobackup.log"

echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for TASK in "${TASKS[@]}"
do

CONTENT=`cat $LOG | grep "task" | grep "\[$TASK\]" | tail -1`
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

echo "<result><channel>$TASK: Time passed</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>$TASK: Status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result>"
done
echo "</prtg>"
exit
