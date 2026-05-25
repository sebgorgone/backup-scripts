#!/bin/bash

start=$(date +%s)

source "$(dirname "$0")/environment"

echo "[ Start Backup ] running molasses01 backup script - $(date)" >>"$backupDir/molasses01-backup-log"

rsync -av --delete --update "$HOME/.msysm-scripts/" "$backupDir/msysm-scripts"
echo "[ rsync ] successfully synced msysm-scripts to backup drive" >>"$backupDir/molasses01-backup-log"

rsync -av --delete --update "$HOME/backup-scripts/" "$backupDir/backup-scripts"
echo "[ rsync ] successfully synced backup-scripts to backup drive" >>"$backupDir/molasses01-backup-log"

cp "$HOME/.ssh/m01-key" "$backupDir/keys/"
echo "[ cp ] successfully backed up m01-key" >>"$backupDir/molasses01-backup-log"

cp "$HOME/seeba-key.pem" "$backupDir/keys/"
echo "[ cp ] successfully backed up seeba-key.pem" >>"$backupDir/molasses01-backup-log"

cp "$HOME/.ssh/ghCD" "$backupDir/keys/"
echo "[ cp ] successfully backed up ghCD" >>"$backupDir/molasses01-backup-log"

cp "$HOME/.ssh/id_ed25519" "$backupDir/keys/"
echo "[ cp ] successfully backed up id_ed25519" >>"$backupDir/molasses01-backup-log"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] backup completed in ${t}s" >>"$backupDir/molasses01-backup-log"
