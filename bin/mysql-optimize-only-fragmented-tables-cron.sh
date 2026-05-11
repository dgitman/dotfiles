#!/usr/bin/env bash
set -euo pipefail

mysql -NBe "SHOW DATABASES;" | grep -Ev '^(lost\+found|information_schema|performance_schema|mysql|sys)$' \
    | while IFS= read -r database ; do

    mysql -NBe "SHOW TABLE STATUS;" "$database" \
        | while read -r name _engine _version _rowformat _rows _avgrowlength \
            _datalength _maxdatalength _indexlength datafree _autoincrement \
            _createtime _updatetime _checktime _collation _checksum \
            _createoptions _comment ; do

        #skip views                                
        if [ "$datafree" = "NULL" ] ; then
            continue
        fi
        if [ "$datafree" -gt 0 ] ; then
            echo "$database.$name is fragmented"
            mysql -NBe "OPTIMIZE TABLE $name;" "$database"
        fi
    done
done
