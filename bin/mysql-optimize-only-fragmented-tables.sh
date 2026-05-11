#!/usr/bin/env bash
set -euo pipefail

echo -n "MySQL username: " ; read -r username
echo -n "MySQL password: " ; read -r -s password ; echo

mysql -u "$username" -p"$password" -NBe "SHOW DATABASES;" \
  | grep -Ev '^(lost\+found|information_schema|performance_schema|mysql|sys)$' \
  | while IFS= read -r database ; do
mysql -u "$username" -p"$password" -NBe "SHOW TABLE STATUS;" "$database" | while read -r name _engine _version _rowformat _rows _avgrowlength datalength _maxdatalength _indexlength datafree _autoincrement _createtime _updatetime _checktime _collation _checksum _createoptions _comment ; do
  if [ "$datafree" != "NULL" ] && [ "$datafree" -gt 0 ] && [ "$datalength" -gt 0 ] ; then
   fragmentation=$((datafree * 100 / datalength))
   echo "$database.$name is $fragmentation% fragmented."
   mysql -u "$username" -p"$password" -NBe "OPTIMIZE TABLE $name;" "$database"
  fi
done
done
