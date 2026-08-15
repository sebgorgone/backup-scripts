#!/bin/bash

set -euo pipefail

start=$(date +%s)
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

source "$scriptDir/environment"

: "${backupDir:?backupDir must be configured}"
: "${molasses02LogPath:?molasses02LogPath must be configured}"
: "${startTunnelsServicePath:?startTunnelsServicePath must be configured}"
: "${molasses02StartTunnelsServiceBackupPath:?startTunnelsServiceBackupPath must be configured}"
: "${molasses02UserCrontabBackupPath:?molassesUserCrontabBackupPath must be configured}"
: "${molasses02RootCrontabBackupPath:?molassesRootCrontabBackupPath must be configured}"
: "${keyPath:?keyPath must be configured}"
: "${backupAddr:?backupAddr must be configured}"

# if [[ ! -d $backupDir ]]; then
#   echo "[ Error ] backup directory does not exist: $backupDir" >&2
#   exit 1
# fi

exec >>"$molasses02LogPath" 2>&1

handleExit() {
  local status=$?
  trap - EXIT

  if ((status != 0)); then
    local end elapsed
    end=$(date +%s)
    elapsed=$((end - start))
    echo "[ Error ] molasses02 backup failed after ${elapsed}s (exit $status)"
  fi

  exit "$status"
}

trap handleExit EXIT

echo "[ Start Backup ] running molasses02 backup script - $(date)"

scp -i $keyPath $startTunnelsServicePath ass@"$backupAddr":"$molasses02startTunnelsServiceBackupPath"
echo "[ scp ] successfully synced start_tunnels config to backup drive"

crontab -l >/tmp/root-molasses02-crontab
scp -i "$keyPath" /tmp/root-molasses02-crontab ass@"$backupAddr":"$molasses02RootCrontabBackupPath"
echo "[ scp ] successfully backed up the root user's crontab file"

sudo -u ass crontab -l >/tmp/$(whoami)-molasses02-crontab
scp -i "$keyPath" /tmp/ass-molasses02-crontab ass@"$backupAddr":"$molasses02UserCrontabBackupPath"
echo "[ scp ] successfully backed up the user crontab file"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] backup completed in ${t}s"

exit 0
