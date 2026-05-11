#!/bin/sh                                                                                                                                                          
mysql -NBe "SHOW DATABASES;" | grep -v 'lost+found' \
    | while read database ; do

    #skip system-db                                       
    if [ "$database" = "mysql" ] ; then
        continue
    fi
    mysql -NBe "SHOW TABLE STATUS;" $database \
        | while read name engine version rowformat rows avgrowlength \
            datalength maxdatalength indexlength datafree autoincrement \
            createtime updatetime checktime collation checksum \
            createoptions comment ; do

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
