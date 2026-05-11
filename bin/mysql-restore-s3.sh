#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Please specify the table you want to download"
    echo "Usage:"
    echo "    $0 <database>.<table_name> [s3_bucket_path]"
    echo ""
    echo "Example:"
    echo "    $0 yourdb_site.users yourbucket/mysql/backup/"
    exit 1
fi

table_name=$1
bucket=${2:-yourbucket/mysql/backup/}
bucket=${bucket#s3://}

# Grep: for directories only
# sort: by number (epoch is the first part of the directory name
# tail -n1: grab the last one (most recent)
# awk: print just the bucket name
latest_backup=$(s3cmd ls "s3://$bucket" | grep DIR | sort -n | tail -n1 | awk -F's3://' '{print $2}' || true)
if [ -z "$latest_backup" ]; then
    echo "Could not find any backup directories in s3://$bucket" >&2
    exit 2
fi

echo "Found latest backup bucket: $latest_backup"

echo "Searching for $table_name..."

all_tables=$(s3cmd --include="$table_name" ls "s3://$latest_backup*")

table_archive=$(echo "$all_tables" | grep "$table_name.sql.gz" | awk -F's3://' '{print $2}' || true)

echo "Found archive for $table_name: $table_archive"

if [ -z "$table_archive" ]; then
    echo "Could not find an archive for $table_name"
    exit 3
fi


tmpfile=$(mktemp "/tmp/${table_name}.XXXXXX.sql")
echo "Downloading into $tmpfile.gz"
s3cmd get "s3://$table_archive" "$tmpfile.gz"

gunzip "$tmpfile.gz"

echo "Done!"
echo "Run this command to import the data:"
echo "mysql your_database -uyour_user -p < $tmpfile"
