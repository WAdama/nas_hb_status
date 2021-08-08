#!/bin/bash
# Version 1.2.7

source $1

echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for TASK in "${TASKS[@]}"
do
CONTENT=$(awk "/Backup task/ && /\[$TASK\]/" $LOG | tail -1)
if [ -z "${CONTENT}" ]; then
	CONTENT=$(awk "/Backup task/ && /\[$TASK\]/" $LOGROTATED | tail -1)
fi
INTEGRITY=$(awk "/integrity check/ && /\[$TASK\]/" $LOG | tail -1)
if [ -z "${INTEGRITY}" ]; then
	INTEGRITY=$(awk "/integrity check/ && /\[$TASK\]/" $LOGROTATED | tail -1)
fi
TASKID=$(awk "/Backup task/ && /\[$TASK\]/" $SYSLOG | tail -1 | sed -n "s/^.*: (\s*\([0-9]*\).*$/\1/p")
if [ -z "${TASKID}" ]; then
	RUNTIME="0"
	BKPSIZE="0"
	LASTBKPSIZE="0"
	else
	RUNTIME=$(awk "/Backup task/ && /\[$TASK\]/" $SYSLOG | tail -1 | sed -n "s/^.*Time spent: \[\s*\([0-9]*\).*$/\1/p")
	BKPSIZE=$(awk "/img_backup/ && /$TASKID/ && /Storage Statistics/" $SYSLOG | tail -1 | sed -n "s/^.*: TargetSize(KB):\[\s*\([0-9]*\).*$/\1/p")
	LASTBKPSIZE=$(awk "/img_backup/ && /$TASKID/ && /Storage Statistics/" $SYSLOG | tail -1 | sed -n "s/^.*LastBackupTargetSize(KB):\[\s*\([0-9]*\).*$/\1/p")
fi
TIME=$(awk "/Backup task/ && /\[$TASK\]/" $LOG | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
if [ -z "${TIME}" ]; then
	TIME=$(awk "/Backup task/ && /\[$TASK\]/" $LOGROTATED | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
fi
INTTIME=$(awk "/Backup integrity check/ && /\[$TASK\]/" $LOG | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
if [ -z "${INTTIME}" ]; then
	INTTIME=$(awk "/Backup integrity check/ && /\[$TASK\]/" $LOGROTATED | tail -1 | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")


fi
TIMEEND=$(date -d "$TIME" +%s)
INTTIMEEND=$(date -d "$INTTIME" +%s)

case $CONTENT in
	*"finished successfully"*) STATUS="1" 	;;
	*"Failed"*) STATUS="2" ;;
	*"created"*) STATUS="3" ;;
	*"started"*) STATUS="4" ;;
	*"cancelled"*) STATUS="5" ;;
	*"suspension complete"*) STATUS="6" ;;
	*"resume backup"*) STATUS="7" ;;
	*"partially completed"*) STATUS="8" ;;
esac

case $INTEGRITY in
	*"No error was found"*) INTSTATUS="1" 	;;
	*"has started"*) INTSTATUS="2" ;;
	*"target is found broken"*) INTSTATUS="3" ;;
	*"Failed to run backup integrity check"*) INTSTATUS="4" ;;
	*) INTSTATUS="0" ;;
esac

ACTTIME=$(date +%s)
LASTRUN=$(($ACTTIME - $TIMEEND))
INTLASTRUN=$(($ACTTIME - $INTTIMEEND))

BKPCHANGE=$(($BKPSIZE - $LASTBKPSIZE))

echo "<result><channel>$TASK: Last backup</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>$TASK: Status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.hbstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$TASK: Runtime</channel><value>$RUNTIME</value><unit>TimeSeconds</unit></result><result><channel>$TASK: Size</channel><value>$(($BKPSIZE * 1024))</value><unit>BytesDisk</unit></result><result><channel>$TASK: Change</channel><value>$(($BKPCHANGE * 1024))</value><unit>BytesDisk</unit></result><result><channel>$TASK: Integrity Check</channel><value>$INTSTATUS</value><ValueLookup>prtg.standardlookups.nas.hbintstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>$TASK: Last integrity check</channel><value>$INTLASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>608400</LimitMaxWarning><LimitMaxError>694800</LimitMaxError></result>"
done
echo "</prtg>"
exit
