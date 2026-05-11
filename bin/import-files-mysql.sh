#!/usr/bin/env bash
set -euo pipefail

# import-files-mysql.sh
# Descr: Import separate SQL files for a specified database.
# Usage: Run without args for usage info.
# Author: Will Rubel
# Notes:
#  * Script will prompt for password for db access.

usage() {
    echo "Usage: $(basename "$0") <DB_HOST> <DB_USER> <DB_NAME> [<DIR>]" >&2
}

[ $# -lt 3 ] && usage && exit 1

DB_host=$1
DB_user=$2
DB=$3
DIR=${4:-.}

echo -n "DB password: "
read -r -s DB_pass
echo
echo "Importing compressed SQL files from '$DIR' into database '$DB'"

file_count=0

shopt -s nullglob
for f in "$DIR"/*.sql.gz; do
    echo "IMPORTING FILE: $f"

    gunzip -c "$f" | mysql -h "$DB_host" -u "$DB_user" -p"$DB_pass" "$DB"

    (( file_count++ ))
done

echo "$file_count files imported to database '$DB'"
