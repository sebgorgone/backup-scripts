#!/bin/bash

set -euo pipefail

start=$(date +%s)
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if ((EUID != 0)); then
  echo "[ Error ] molasses02-backup.sh must be run as root" >&2
  exit 1
fi

source "$scriptDir/environment"

: "${backupDir:?backupDir must be configured}"
: "${molasses02LogPath:?molasses02LogPath must be configured}"
: "${startTunnelsServicePath:?startTunnelsServicePath must be configured}"
: "${molasses02StartTunnelsServiceBackupPath:?startTunnelsServiceBackupPath must be configured}"
: "${molasses02UserCrontabBackupPath:?molassesUserCrontabBackupPath must be configured}"
: "${molasses02RootCrontabBackupPath:?molassesRootCrontabBackupPath must be configured}"
: "${keyPath:?keyPath must be configured}"
: "${backupAddr:?backupAddr must be configured}"
: "${molasses02SudoersPath:?molasses02SudoersPath must be configured}"
: "${molasses02SudoersBackupPath:?molasses02SudoersBackupPath must be configured}"
: "${molasses02FstabPath:?molasses02SudoersPath must be configured}"
: "${molasses02FstabBackupPath:?molasses02SudoersBackupPath must be configured}"

sshOptions=(
  -i "$keyPath"
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=accept-new
)
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

copyLocalFile() {
  local sourcePath destinationPath
  sourcePath=$1
  destinationPath=$2
  activeBackupTemp="${destinationPath}.tmp.${runToken}"

  cat -- "$sourcePath" |
    streamBackupTemp "$activeBackupTemp"
  promoteBackupTemp "$activeBackupTemp" "$destinationPath"
  activeBackupTemp=
}

copyCommandOutput() {
  local destinationPath
  destinationPath=$1
  shift
  activeBackupTemp="${destinationPath}.tmp.${runToken}"

  "$@" |
    streamBackupTemp "$activeBackupTemp"
  promoteBackupTemp "$activeBackupTemp" "$destinationPath"
  activeBackupTemp=
}

handleExit() {
  local status=$?
  trap - EXIT

  if ((status != 0)); then
    local end elapsed
    end=$(date +%s)
    elapsed=$((end - start))
    echo "[ Error ] molasses02 backup failed after ${elapsed}s (exit $status)"
    if [[ -n $activeBackupTemp ]]; then
      removeBackupTemp "$activeBackupTemp" ||
        echo "[ Error ] unable to remove remote temporary file: $activeBackupTemp"
    fi
  fi

  exit "$status"
}

backupDirQuoted=$(quoteRemote "$backupDir")
if ! ssh "${sshOptions[@]}" "$backupHost" \
  "set -eu
backupDir=$backupDirQuoted
[ -d \"\$backupDir\" ] && [ -w \"\$backupDir\" ]"; then
  echo "[ Error ] remote backup directory is not writable: ass@$backupAddr:$backupDir" >&2
  exit 1
fi

remoteLogPath=$(quoteRemote "$molasses02LogPath")
exec > >(
  ssh "${sshOptions[@]}" "$backupHost" "cat >> $remoteLogPath"
) 2>&1

trap handleExit EXIT

echo "[ Start Backup ] running molasses02 backup script - $(date)"

copyLocalFile "$startTunnelsServicePath" "$molasses02StartTunnelsServiceBackupPath"
echo "[ copy ] successfully synced start_tunnels config to backup host"

copyCommandOutput "$molasses02RootCrontabBackupPath" crontab -l
echo "[ copy ] successfully backed up the root user's crontab file"

copyCommandOutput "$molasses02UserCrontabBackupPath" crontab -u ass -l
echo "[ copy ] successfully backed up the ass user's crontab file"

copyLocalFile "$molasses02SudoersPath" "$molasses02SudoersBackupPath"
echo "[ copy ] successfully backed up the sudoers file"

copyLocalFile "$molasses02FstabPath" "$molasses02FstabBackupPath"
echo "[ copy ] successfully backed up the fstab file"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] backup completed in ${t}s"

exit 0
