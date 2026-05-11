# bin

Personal scripts and command-line helpers.

## Commands

| Command | Purpose |
| --- | --- |
| `aws-s3-list-all-bucket-sizes.sh` | Print S3 bucket sizes using `s3cmd`. |
| `beautify_bash.py` | Reformat a bash script for readability. |
| `curl-format-example.sh [url]` | Run `curl` with the bundled timing format file. |
| `dump-tables-mysql.sh <host> <user> <database> [dir]` | Dump each table in a MySQL database into its own compressed SQL file. |
| `duplicity-backup.sh` | Run Duplicity encrypted backups (via submodule). |
| `file2folder.sh` | Move each file in the current directory into a same-named folder. |
| `import-files-mysql.sh <host> <user> <database> [dir]` | Import `.sql.gz` files into a MySQL database. |
| `modman` | Magento module manager (via submodule). |
| `mysql-backup-s3.sh` | Back up all MySQL databases per-table to Amazon S3. |
| `mysql-dbs-restore.sh` | Restore multiple MySQL databases from `.sql` files (filename = db name). |
| `mysql-dump-databases.sh <host> <user> [dir]` | Dump user databases from a MySQL server into compressed files. |
| `mysql-optimize-only-fragmented-tables.sh` | Prompt for MySQL credentials and optimize fragmented tables. |
| `mysql-optimize-only-fragmented-tables-cron.sh` | Cron-friendly version of the fragmented table optimizer. |
| `mysql-restore-s3.sh <database.table> [bucket/path]` | Download a table archive from the latest S3 backup. |
| `mysqltuner.pl` | Analyze a MySQL server and suggest performance tuning (via submodule). |
| `rename-db.sh <server> <database> <new_database>` | Rename a MySQL database by moving all tables to a new schema. |
| `s3cmd` | S3 command-line tool (via submodule). |
| `speed-test.sh <user@host[:port]> [size_kb]` | Test SSH upload/download throughput with `scp`. |
| `tuning-primer.sh` | MySQL performance tuning primer script (legacy, read-only analysis). |
| `update-pingdom-iptables.sh [-n]` | Update a `PINGDOM` iptables chain from Pingdom probe IPs. |
| `xtrabackup-s3-backup.sh` | Run Percona XtraBackup and upload the result to Amazon S3. |

## Notes

- The scripts assume the required tools are already installed, such as `mysql`, `mysqldump`, `s3cmd`, `aws`, `curl`, `scp`, and `iptables`.
- MySQL scripts prompt for passwords instead of storing credentials in the script files.
- For S3 and AWS scripts, configure credentials through the standard tool config files or environment variables.
