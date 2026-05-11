#!/bin/sh 
# Optional variables for a backup script
MYSQL_HOST="your-mysql-host"
MYSQL_USER="your-mysql-user"
MYSQL_PASS=""
BACKUP_DIR=/~/backup/$(date +%Y-%m-%dT%H_%M_%S);

test -d "$BACKUP_DIR" || mkdir -p "$BACKUP_DIR"
# Get the database list, exclude information_schema
for db in $(mysql -B -s -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASS -e 'show databases' | grep -v information_schema)
do
  # dump each database in a separate file
  mysqldump -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASS "$db" | gzip > "$BACKUP_DIR/$db.sql.gz"
done