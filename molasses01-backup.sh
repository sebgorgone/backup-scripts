#!/bin/bash

set -euo pipefail

start=$(date +%s)
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

source "$scriptDir/environment"

: "${backupDir:?backupDir must be configured}"
: "${molassesLogPath:?molassesLogPath must be configured}"
: "${msysmScriptsSourceDir:?msysmScriptsSourceDir must be configured}"
: "${msysmScriptsBackupDir:?msysmScriptsBackupDir must be configured}"
: "${backupScriptsSourceDir:?backupScriptsSourceDir must be configured}"
: "${backupScriptsBackupDir:?backupScriptsBackupDir must be configured}"
: "${startTunnelsServicePath:?startTunnelsServicePath must be configured}"
: "${startTunnelsServiceBackupPath:?startTunnelsServiceBackupPath must be configured}"
: "${sambaConfigPath:?sambaConfigPath must be configured}"
: "${sambaConfigBackupPath:?sambaConfigBackupPath must be configured}"
: "${molassesUserCrontabBackupPath:?molassesUserCrontabBackupPath must be configured}"
: "${keyPath:?keyPath must be configured}"
: "${keyBackupPath:?keyBackupPath must be configured}"
: "${seebaKeyPath:?seebaKeyPath must be configured}"
: "${seebaKeyBackupPath:?seebaKeyBackupPath must be configured}"
: "${ghCDKeyPath:?ghCDKeyPath must be configured}"
: "${ghCDKeyBackupPath:?ghCDKeyBackupPath must be configured}"
: "${ed25519KeyPath:?ed25519KeyPath must be configured}"
: "${ed25519KeyBackupPath:?ed25519KeyBackupPath must be configured}"

if [[ ! -d $backupDir ]]; then
  echo "[ Error ] backup directory does not exist: $backupDir" >&2
  exit 1
fi

exec >>"$molassesLogPath" 2>&1

handleExit() {
  local status=$?
  trap - EXIT

  if ((status != 0)); then
    local end elapsed
    end=$(date +%s)
    elapsed=$((end - start))
    echo "[ Error ] molasses01 backup failed after ${elapsed}s (exit $status)"
  fi

  exit "$status"
}

trap handleExit EXIT

echo "[ Start Backup ] running molasses01 backup script - $(date)"

rsync -av --delete --update "$msysmScriptsSourceDir" "$msysmScriptsBackupDir"
echo "[ rsync ] successfully synced msysm-scripts to backup drive"

rsync -av --delete --update "$backupScriptsSourceDir" "$backupScriptsBackupDir"
echo "[ rsync ] successfully synced backup-scripts to backup drive"

cat -- "$startTunnelsServicePath" >"$startTunnelsServiceBackupPath"
echo "[ cat ] successfully synced start_tunnels config to backup drive"

cat -- "$sambaConfigPath" >"$sambaConfigBackupPath"
echo "[ cat ] successfully synced smb.conf to backup drive"

crontab -l >"$molassesUserCrontabBackupPath"
echo "[ sync ] successfully backed up the user's crontab file"

cp -- "$keyPath" "$keyBackupPath"
echo "[ cp ] successfully backed up m01-key"

cp -- "$seebaKeyPath" "$seebaKeyBackupPath"
echo "[ cp ] successfully backed up seeba-key.pem"

cp -- "$ghCDKeyPath" "$ghCDKeyBackupPath"
echo "[ cp ] successfully backed up ghCD"

cp -- "$ed25519KeyPath" "$ed25519KeyBackupPath"
echo "[ cp ] successfully backed up id_ed25519"

cp -- "$msysmConfigPath" "$msysmConfigBackupPath"
echo "[ cp ] succesfully backed up molassysmon config"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] backup completed in ${t}s"

exit 0
