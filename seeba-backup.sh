#!/bin/bash

source "$(dirname "$0")/environment"
rsync -av --delete --update "$seebaUploadDir/" "$backupDir/seebaUploads"
mysqldump --no-tablespaces seeba_db | gzip > "$backupDir/seeba.sql.gz"
cp $seebaENV "$backupDir/seeba-env"
cp $seebaSystemdConf "$backupDir/seeba-systemd"
