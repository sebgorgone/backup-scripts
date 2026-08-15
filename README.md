# Personal backup scripts

These scripts back up configurations, databases, environment variables, and
other files that would be difficult to recreate.

They are configurable, but tailored to a specific environment and may be most
useful as a guide.

## Cloudlog backup

`cloudlog-backup.sh` can run from any machine that can reach both the Cloudlog
host and backup server over SSH. It executes `mysqldump` on the Cloudlog host
and streams all data through the invoking machine to the backup server. It does
not require a local backup mount or create local copies of the backup data.

The gitignored `environment` file must define:

```bash
keyPath=$HOME/.ssh/m01-key
backupDir=/mnt/networkdrive2/backups
backupAddr=192.168.1.133
cloudLogAddr=192.168.1.109
cloudlogENV=/home/ass/Cloud-Log/Server/.env
cloudlogSystemdConf=/etc/systemd/system/cloudlog-server.service

molassesLogPath=$backupDir/molasses01-backup-log
msysmScriptsSourceDir=$HOME/.msysm-scripts/
msysmScriptsBackupDir=$backupDir/msysm-scripts
backupScriptsSourceDir=$HOME/backup-scripts/
backupScriptsBackupDir=$backupDir/backup-scripts
startTunnelsServicePath=/etc/systemd/system/start_tunnels.service
startTunnelsServiceBackupPath=$backupDir/molasses01-start_tunnels-systemd
sambaConfigPath=/etc/samba/smb.conf
sambaConfigBackupPath=$backupDir/molasses01-smb.conf
molassesUserCrontabBackupPath=$backupDir/$(whoami)-crontab
keyBackupPath=$backupDir/keys/m01-key
seebaKeyPath=$HOME/.ssh/seeba-key.pem
seebaKeyBackupPath=$backupDir/keys/seeba-key.pem
ghCDKeyPath=$HOME/.ssh/ghCD
ghCDKeyBackupPath=$backupDir/keys/ghCD
ed25519KeyPath=$HOME/.ssh/id_ed25519
ed25519KeyBackupPath=$backupDir/keys/id_ed25519

sudoMolassesLogPath=$backupDir/sudo-molasses01-backup-log
sudoersPath=/etc/sudoers
sudoersBackupPath=$backupDir/molasses01-sudoers
rootCrontabBackupPath=$backupDir/molasses01-root-crontab
fstabPath=/etc/fstab
fstabBackupPath=$backupDir/molasses01-fstab
```

The `ass` account and configured key are used for both SSH endpoints. On the
first connection, SSH adds new host keys to the invoking user's `known_hosts`
file. Changed host keys are still rejected and must be verified and updated
manually. Confirm that public-key authentication works with `BatchMode=yes`.
The Cloudlog host must allow `ass` to run `mysqldump` for `cloudlog_db` without
an interactive database password. The backup server must allow `ass` to write
to `backupDir`.

Each successful run atomically replaces these files on the backup server:

- `cloudlog.sql.gz`
- `cloudlog-env`
- `cloudlog-systemd`

Stdout and stderr are streamed over SSH and appended directly to
`backupDir/cloudlog-backup-log`. No local log file is written.

## Molasses01 backup

`molasses01-backup.sh` backs up the configured user files, system
configuration, crontab, and SSH keys. Every operational source, destination,
and log path is configured in `environment`; the script-relative
`environment` path is the only bootstrap exception.

The script validates its required configuration and backup directory before
starting. All subsequent stdout, stderr, step status, and final success or
failure information is appended to `molassesLogPath`.

## Molasses01 root backup

`sudo-molasses01-backup.sh` backs up root-owned system configuration and the
root crontab. Run it from root's crontab or invoke it manually with:

```bash
sudo ./sudo-molasses01-backup.sh
```

The script exits with a clear error when run without root privileges. All
stdout, stderr, step status, and final success or failure information is
appended to `sudoMolassesLogPath`. Its source, destination, and log paths are
configured in the same `environment` file as the non-root backup.
