#!/bin/bash


start=$(date +%s)


source "$(dirname "$0")/environment"

echo "[ Start Backup ] running seeba backup script - $(date)" >> "$backupDir/seeba-backup-log"

rsync -av --delete --update "$seebaUploadDir/" "$backupDir/seebaUploads"
echo "[ rsync ] succesfully synced uploads from seeba to backup drive" >> "$backupDir/seeba-backup-log"

mysqldump --no-tablespaces seeba_db | gzip > "$backupDir/seeba.sql.gz"
echo "[ sqldump ] db zipped and storedd in backup drive" >> "$backupDir/seeba-backup-log"

cp $seebaENV "$backupDir/seeba-env"
echo "[ copy ] .env backed up to drive" >> "$backupDir/seeba-backup-log"

cp $seebaSystemdConf "$backupDir/seeba-systemd"
echo "[ copy ] systdemd config backed up to drive" >> "$backupDir/seeba-backup-log"

end=$(date +%s)
t=$((end - start))

echo "[ End Backup ] backup completed in ${t} seconds" >> "$backupDir/seeba-backup-log"
