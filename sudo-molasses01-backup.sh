#!/bin/bash

set -euo pipefail

start=$(date +%s)
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if ((EUID != 0)); then
  echo "[ Error ] sudo-molasses01-backup.sh must be run as root" >&2
  exit 1
fi

source "$scriptDir/environment"

: "${backupDir:?backupDir must be configured}"
: "${sudoMolassesLogPath:?sudoMolassesLogPath must be configured}"
: "${sudoersPath:?sudoersPath must be configured}"
: "${sudoersBackupPath:?sudoersBackupPath must be configured}"
: "${rootCrontabBackupPath:?rootCrontabBackupPath must be configured}"
: "${fstabPath:?fstabPath must be configured}"
: "${fstabBackupPath:?fstabBackupPath must be configured}"
if [[ ! -d $backupDir ]]; then
  echo "[ Error ] backup directory does not exist: $backupDir" >&2
  exit 1
fi

exec >>"$sudoMolassesLogPath" 2>&1

handleExit() {
  local status=$?
  trap - EXIT

  if ((status != 0)); then
    local end elapsed
    end=$(date +%s)
    elapsed=$((end - start))
    echo "[ Error ] molasses01 root backup failed after ${elapsed}s (exit $status)"
  fi

  exit "$status"
}

trap handleExit EXIT

echo "[ Start Backup ] running molasses01 root backup script - $(date)"

cat -- "$sudoersPath" >"$sudoersBackupPath"
echo "[ cat ] sudoers backed up successfully"

crontab -l >"$rootCrontabBackupPath"
echo "[ cron ] root's crontab backed up successfully"

cat -- "$fstabPath" >"$fstabBackupPath"
echo "[ cat ] fstab backed up successfully"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] backup completed in ${t}s"

exit 0
