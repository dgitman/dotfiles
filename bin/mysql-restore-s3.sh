#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Please specify the table you want to download"
    echo "Usage:"
    echo "    $0 <database>.<table_name>"
    echo ""
    echo "Example:"
    echo "    $0 yourdb_site.users"
    exit 1
fi

bucket='yourbucket/mysql/backup/'

# Grep: for directories only
# sort: by number (epoch is the first part of the directory name
# tail -n1: grab the last one (most recent)
# awk: print just the bucket name
latest_backup=$(s3cmd ls s3://$bucket | grep DIR | sort -n | tail -n1 | awk -"Fs3://" '{print $2}' )

echo "Found latest backup bucket: $latest_backup"

echo "Searching for $1..."

all_tables=$(s3cmd --include="$1" ls "s3://$latest_backup*")

table_archive=$(echo "$all_tables" | grep "$1.sql.gz" | awk -"Fs3://" '{print $2}')

echo "Found archive for $1: $table_archive"

if [ -z "$table_archive" ]; then
    echo "Could not find an archive for $1"
    exit 2
fi


tmpfile=/tmp/$1.sql
echo "Downloading into $tmpfile.gz"
s3cmd get "s3://$table_archive" "$tmpfile.gz"

gunzip $tmpfile.gz

echo "Done!"
echo "Run this command to import the data:"
echo "mysql your_database -uyour_user -p < $tmpfile"
