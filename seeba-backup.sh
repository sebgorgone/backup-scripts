#!/bin/bash

source "$(dirname "$0")/environment"
rsync -av --delete --update "$seebaUploadDir/" "$backupDir/seebaUploads"
mysqldump --no-tablespaces seeba_db > "$backupDir/seeba.sql"
cp $seebaENV "$backupDir/seeba-env"
cp $seebaSystemdConf "$backupDir/seeba-systemd"
