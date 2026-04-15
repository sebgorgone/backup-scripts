#!/bin/bash

start=$(date +%s)
logfile="cloudlog-backup-log"

exec > >(tee -a "$logfile" | ssh -i "$keyPath" ass@"$backupAddr" "cat >> '$backupDir/cloudlog-backup-log'") 2>&1


echo "[ Start Backup ] beginning cloudlog backup - $(date)"

set -e
source "$(dirname "$0")/environment"

mysqldump --single-transaction --no-tablespaces cloudlog_db \
  | gzip \
  | ssh -i "$keyPath" "ass@$backupAddr" \
    "cat > '$backupDir/cloudlog.sql.gz'"
echo "[ sqldump ] db successfully zipped and stored in backup drive"

scp -i "$keyPath" "$cloudlogENV" "ass@$backupAddr:$backupDir/cloudlog-env"
echo "[ copy ] .env succesfully backed up"

scp -i "$keyPath" "$cloudlogSystemdConf" "ass@$backupAddr:$backupDir/cloudlog-systemd"
echo "[ copy ] systemd configuration succesfully backed up"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] cloudlog backed up in ${t}s"
