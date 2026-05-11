#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: mysql-dump-databases.sh <mysql_host> <mysql_user> [backup_dir]

The script prompts for the MySQL password so credentials are not stored here.
EOF
}

[ $# -lt 2 ] && usage && exit 1

MYSQL_HOST=$1
MYSQL_USER=$2
BACKUP_DIR=${3:-"$HOME/backup/$(date +%Y-%m-%dT%H_%M_%S)"}

echo -n "MySQL password: "
read -r -s MYSQL_PASS
echo

mkdir -p "$BACKUP_DIR"
# Get the database list, exclude information_schema
mysql -B -s -h "$MYSQL_HOST" -u "$MYSQL_USER" --password="$MYSQL_PASS" -e 'show databases' \
  | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' \
  | while IFS= read -r db; do
  # dump each database in a separate file
  echo "Dumping $db"
  mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" --password="$MYSQL_PASS" "$db" | gzip > "$BACKUP_DIR/$db.sql.gz"
done

echo "Backups written to $BACKUP_DIR"
