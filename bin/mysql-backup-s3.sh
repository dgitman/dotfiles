#!/bin/bash
# ------------------------------------------------------------------
#                  MySQL Backup to Amazon S3
#        This backups all MySQL datatbases on a per tables basis to Amazon S3
# ------------------------------------------------------------------

# -----------------------------------------------------------------
#  Describing variables
# -----------------------------------------------------------------

bucket="s3://ndap-etl-database-backup" # Set S3cmd path
IFS=$(echo -en "\n\b") 	# Fix for loop issue with spaces in name by setting internal field separator to a new line

# -----------------------------------------------------------------
#  Log start of MySQL backup to Amazon S3
# -----------------------------------------------------------------

echo "Starting MySQL Backup to Amazon S3 bucket $bucket on ($date)"

# -----------------------------------------------------------------
#  List all databases
# -----------------------------------------------------------------

databases=`mysql --batch --skip-column-names -e "SHOW DATABASES;" | grep -v "\(Database\|information_schema\|performance_schema\|mysql\|test\)"`

# -----------------------------------------------------------------
#  Loop through the databases
# -----------------------------------------------------------------

for db in $databases; do
  
  filename="$db.routines.sql.gz"
  tmpfile="/tmp/$filename"
  object="$bucket/$filename"
  
  # -----------------------------------------------------------------
  #  mysqldump routines (stored procedures/functions)
  # -----------------------------------------------------------------
  
  mysqldump --routines --no-create-info --no-data --no-create-db --skip-opt "$db" | gzip -c > "$tmpfile"
  s3cmd -q put "$tmpfile" "$object"	# Copy to Amazon S3
  rm -f "$tmpfile" 			# Delete tmp file
  
  # -----------------------------------------------------------------
  #  List all tables
  # -----------------------------------------------------------------
  
  tables=`mysql --batch --skip-column-names $db -e "SHOW TABLES;"`
  
  # -----------------------------------------------------------------
  #  Loop through the tables
  # -----------------------------------------------------------------
  
  for tb in $tables; do
    filename="$db.$tb.sql.gz"
    tmpfile="/tmp/$filename"
    object="$bucket/$filename"
    echo -e "$db"."$tb"
    
    # -----------------------------------------------------------------
    #  mysqldump tables
    # -----------------------------------------------------------------
    
    mysqldump --opt --max_allowed_packet=512M --databases "$db" --tables "$tb" | gzip -c > "$tmpfile"
    s3cmd -q put "$tmpfile" "$object"	# Copy to Amazon S3
    rm -f "$tmpfile"			# Delete tmp file
    
  done;
  
done;

# -----------------------------------------------------------------
# Log completion of MySQL backup to Amazon S3
# -----------------------------------------------------------------

echo "Completed MySQL Backup to Amazon S3 bucket $bucket on ($date)"
