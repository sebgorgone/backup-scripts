#!/bin/bash

set -euo pipefail

start=$(date +%s)
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$scriptDir/environment"

: "${keyPath:?keyPath must be configured}"
: "${cloudLogAddr:?cloudLogAddr must be configured}"
: "${backupAddr:?backupAddr must be configured}"
: "${backupDir:?backupDir must be configured}"
: "${cloudlogENV:?cloudlogENV must be configured}"
: "${cloudlogSystemdConf:?cloudlogSystemdConf must be configured}"

sshOptions=(
  -i "$keyPath"
  -o BatchMode=yes
  -o ConnectTimeout=15
)
cloudlogHost="ass@$cloudLogAddr"
backupHost="ass@$backupAddr"
runToken="$(date +%s)-$$"
activeBackupTemp=

quoteRemote() {
  printf "'%s'" "${1//\'/\'\\\'\'}"
}

streamBackupTemp() {
  local tempPath tempPathQuoted
  tempPath=$1
  tempPathQuoted=$(quoteRemote "$tempPath")

  ssh "${sshOptions[@]}" "$backupHost" \
    "set -eu
temp=$tempPathQuoted
trap 'rm -f -- \"\$temp\"' 0 HUP INT TERM
umask 077
cat >\"\$temp\"
trap - 0 HUP INT TERM"
}

promoteBackupTemp() {
  local tempPath destinationPath tempPathQuoted destinationPathQuoted
  tempPath=$1
  destinationPath=$2
  tempPathQuoted=$(quoteRemote "$tempPath")
  destinationPathQuoted=$(quoteRemote "$destinationPath")

  ssh "${sshOptions[@]}" "$backupHost" \
    "mv -f -- $tempPathQuoted $destinationPathQuoted"
}

removeBackupTemp() {
  local tempPathQuoted
  tempPathQuoted=$(quoteRemote "$1")
  ssh "${sshOptions[@]}" "$backupHost" "rm -f -- $tempPathQuoted"
}

handleExit() {
  local status=$?
  trap - EXIT

  if ((status != 0)); then
    echo "[ Error ] cloudlog backup failed (exit $status)"
    if [[ -n $activeBackupTemp ]]; then
      removeBackupTemp "$activeBackupTemp" ||
        echo "[ Error ] unable to remove remote temporary file: $activeBackupTemp"
    fi
  fi

  exit "$status"
}

copyCloudlogFile() {
  local sourcePath destinationPath sourcePathQuoted
  sourcePath=$1
  destinationPath=$2
  sourcePathQuoted=$(quoteRemote "$sourcePath")
  activeBackupTemp="${destinationPath}.tmp.${runToken}"

  ssh "${sshOptions[@]}" "$cloudlogHost" "cat -- $sourcePathQuoted" |
    streamBackupTemp "$activeBackupTemp"
  promoteBackupTemp "$activeBackupTemp" "$destinationPath"
  activeBackupTemp=
}

remoteLogPath=$(quoteRemote "$backupDir/cloudlog-backup-log")
exec > >(
  ssh "${sshOptions[@]}" "$backupHost" "cat >> $remoteLogPath"
) 2>&1
trap handleExit EXIT

echo "[ Start Backup ] beginning cloudlog backup - $(date)"

databaseDestination="$backupDir/cloudlog.sql.gz"
activeBackupTemp="${databaseDestination}.tmp.${runToken}"
ssh "${sshOptions[@]}" "$cloudlogHost" \
  "mysqldump --single-transaction --no-tablespaces cloudlog_db" |
  gzip |
  streamBackupTemp "$activeBackupTemp"
promoteBackupTemp "$activeBackupTemp" "$databaseDestination"
activeBackupTemp=
echo "[ sqldump ] database successfully compressed and backed up"

copyCloudlogFile "$cloudlogENV" "$backupDir/cloudlog-env"
echo "[ copy ] .env successfully backed up"

copyCloudlogFile "$cloudlogSystemdConf" "$backupDir/cloudlog-systemd"
echo "[ copy ] systemd configuration successfully backed up"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] cloudlog backed up in ${t}s"
