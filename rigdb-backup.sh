#!/bin/bash

set -euo pipefail

start=$(date +%s)
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$scriptDir/environment"

: "${keyPath:?keyPath must be configured}"
: "${rigDbAddr:?rigDbAddr must be configured}"
: "${backupAddr:?backupAddr must be configured}"
: "${backupDir:?backupDir must be configured}"
: "${rigDbENV:?rigDbENV must be configured}"
: "${rigDbSystemdConf:?rigDbSystemdConf must be configured}"
: "${rigDbDatabase:?rigDbDatabase must be configured}"
: "${rigDbUploads:?rigDbUploads must be configured}"
: "${rigDbBackupKeyPath:?rigDbBackupKeyPath must be configured}"

sshOptions=(
  -i "$keyPath"
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=accept-new
)
rigDbHost="ass@$rigDbAddr"
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
    echo "[ Error ] rigDB backup failed (exit $status)"
    if [[ -n $activeBackupTemp ]]; then
      removeBackupTemp "$activeBackupTemp" ||
        echo "[ Error ] unable to remove remote temporary file: $activeBackupTemp"
    fi
  fi

  exit "$status"
}

copyRigDbFile() {
  local sourcePath destinationPath sourcePathQuoted
  sourcePath=$1
  destinationPath=$2
  sourcePathQuoted=$(quoteRemote "$sourcePath")
  activeBackupTemp="${destinationPath}.tmp.${runToken}"

  ssh "${sshOptions[@]}" "$rigDbHost" "cat -- $sourcePathQuoted" |
    streamBackupTemp "$activeBackupTemp"
  promoteBackupTemp "$activeBackupTemp" "$destinationPath"
  activeBackupTemp=
}

syncRigDbUploads() {
  local sourcePath destinationPath
  local sourcePathQuoted destinationPathQuoted backupKeyPathQuoted
  sourcePath="${rigDbUploads%/}/"
  destinationPath="ass@$backupAddr:${backupDir%/}/rigDB-uploads/"
  sourcePathQuoted=$(quoteRemote "$sourcePath")
  destinationPathQuoted=$(quoteRemote "$destinationPath")
  backupKeyPathQuoted=$(quoteRemote "$rigDbBackupKeyPath")

  ssh "${sshOptions[@]}" "$rigDbHost" \
    "set -eu
sourcePath=$sourcePathQuoted
destinationPath=$destinationPathQuoted
backupKeyPath=$backupKeyPathQuoted
rsync -av --delete --protect-args \
  -e \"ssh -i \\\"\$backupKeyPath\\\" -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new\" \
  -- \"\$sourcePath\" \"\$destinationPath\""
}

remoteLogPath=$(quoteRemote "$backupDir/rigDB-backup-log")
exec > >(
  ssh "${sshOptions[@]}" "$backupHost" "cat >> $remoteLogPath"
) 2>&1
trap handleExit EXIT

echo "[ Start Backup ] beginning rigDB backup - $(date)"

copyRigDbFile "$rigDbDatabase" "$backupDir/rig.db"
echo "[ copy ] SQLite database successfully backed up"

copyRigDbFile "$rigDbENV" "$backupDir/rigDB-env"
echo "[ copy ] .env successfully backed up"

copyRigDbFile "$rigDbSystemdConf" "$backupDir/rigDb-systemd"
echo "[ copy ] systemd configuration successfully backed up"

syncRigDbUploads
echo "[ rsync ] uploads successfully mirrored to backup server"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] rigDB backed up in ${t}s"
