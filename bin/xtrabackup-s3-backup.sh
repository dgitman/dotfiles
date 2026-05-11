#!/bin/bash
# ------------------------------------------------------------------
#                 Backup whole MySQL database instance
#        This runs Percona XtraBackup and copies it to an Amazon S3 bucket 
# ------------------------------------------------------------------

# -----------------------------------------------------------------
#  Describing variables
# -----------------------------------------------------------------

TMPFILE="/tmp/innobackupex.$$.tmp"

countStart() {
        before="$(date +%s)"
}

countEnd() {
        after="$(date +%s)"
	elapsed_seconds=$(expr $after - $before)
}

logWriteBefore() {
	echo "$(date) $1"
}

logWriteAfter() {
	echo "$(date) $1. Elapsed time: $(date -d "1970-01-01 $elapsed_seconds sec" +%H:%M:%S)"
}

# -----------------------------------------------------------------
#  Run innobackupex (wrapper for xtrabackup)
# -----------------------------------------------------------------

countStart
logWriteBefore "Started database backup"
/usr/bin/innobackupex --compress --rsync /backups/database > $TMPFILE 2>&1

if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] 
 then
   echo "$INNOBACKUPEX failed:"
fi

countEnd
logWriteAfter "Completed database backup"

# -----------------------------------------------------------------
#  Remove backups older than 28 days
# -----------------------------------------------------------------

countStart
logWriteBefore "Started database cleanup"

find /backups/database -prune -mtime +7 -exec rm -rf {} \;

countEnd
logWriteAfter "Completed database cleanup"

# -----------------------------------------------------------------
#  Sync to Smazon S3 Bucket
# -----------------------------------------------------------------

countStart
logWriteBefore "Started Amazon S3 Sync"

aws s3 sync /backups s3://ndap-etl-backup --delete --only-show-errors

countEnd
logWriteAfter "Completed Amazon S3 Sync"
