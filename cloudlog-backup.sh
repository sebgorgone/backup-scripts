#!/bin/bash

set -e
source "$(dirname "$0")/environment"

mysqldump --single-transaction --no-tablespaces cloudlog_db \
  | gzip \
  | ssh -i "$keyPath" "ass@$backupAddr" \
    "cat > '$backupDir/cloudlog.sql.gz'"

scp -i "$keyPath" "$cloudlogENV" "ass@$backupAddr:$backupDir/cloudlog-env"
scp -i "$keyPath" "$cloudlogSystemdConf" "ass@$backupAddr:$backupDir/cloudlog-systemd"
