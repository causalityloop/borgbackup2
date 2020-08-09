# BorgBackup2  Docker Image

[![](https://images.microbadger.com/badges/image/causalityloop/borgbackup2.svg)](https://microbadger.com/images/causalityloop/borgbackup2 "Get your own image badge on microbadger.com") [![](https://images.microbadger.com/badges/version/causalityloop/borgbackup2.svg)](https://microbadger.com/images/causalityloop/borgbackup2 "Get your own version badge on microbadger.com")

First and foremost, this is an evolution of the original effort done by [pschiffe](https://github.com/pschiffe/docker-borg) and addresses a number of bug fixes, optimizations, and additions to the original project.

What is BorgBackup? In short, it is an easy to use, secure, data backup program with dedupe capabilities ([Official summary](https://borgbackup.readthedocs.io/en/stable/index.html#what-is-borgbackup))

How does this improve the experience?

This docker image provides:
- lightweight isolated environment to run in
- notifications
- sshfs support
- easy way to backup docker volumes
- backup and prune in one go

Docker image with [BorgBackup](https://borgbackup.readthedocs.io/en/stable/) client utility and sshfs support. Borg is a deduplicating backup program supporting compresion and encryption. It's very efficient and doesn't need regular full backups while still supporting data pruning.

## Quick start
In our example below, we are going to be backing up our [Plex](https://support.plex.tv/articles/200288286-what-is-plex/) metadata.

 - Pull the image to ensure you have the latest
 - Set `ARCHIVE_PREFIX` to what you like. `ARCHIVE_PREFIX` is used in the naming of the snapshot we are creating and also used to name the running container
 - Set the path to your Plex metadata - `/dockers/plex/config`. The container expects an internal data path of `/borg_data/` so just add your path to the end, such as `/borg_data/plex/config`. Also, keep :ro as that defines we are bind mounting as read only. We do not need write access.
 - Set the path where your backup will be stored - `/raid/plex.backup`
 - PRUNE=1 indicates to run a cleanup after creating the backup. Remove or change this to 0 to disable pruning. KEEP_[DAILY, WEEKLY, MONTHLY] can all be tweaked to fit your needs and are defined [here](https://borgbackup.readthedocs.io/en/stable/usage/prune.html)
 - If the host is using SELinux, the `--security-opt label:disable` flag must be used, because we don't want to relabel the data directories
```
ARCHIVE_PREFIX='plex'
docker pull causalityloop/borgbackup2:1.0
docker run \
  --rm \
  -e ARCHIVE=${ARCHIVE_PREFIX}_$(date +%Y-%m-%d_%H.%M.%S) \
  -e EXCLUDE='*/.cache*;*.tmp' \
  -e COMPRESSION=lz4 \
  -e PRUNE=1 \
  -e KEEP_DAILY=3 \
  -e KEEP_WEEKLY=2 \
  -e KEEP_MONTHLY=1 \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  -v /raid/plex.backup:/borg_repo \
  -v /dockers/plex/config:/borg_data/plex/config:ro \
  --security-opt label:disable \
  --name borg-backup2-${ARCHIVE_PREFIX} \
  causalityloop/borgbackup2:1.0
```

## More examples

Perform the same backup above and send the log as a notification to a Rocketchat server

 - On the rocketchat server, you can also use [this](https://github.com/causalityloop/borgbackup2/blob/master/rocketchat.script) script to help integrate
```
ARCHIVE_PREFIX='plex'
docker pull causalityloop/borgbackup2:1.0
docker run \
  --rm \
  -e ARCHIVE=${ARCHIVE_PREFIX}_$(date +%Y-%m-%d_%H.%M.%S) \
  -e EXCLUDE='*/.cache*;*.tmp' \
  -e COMPRESSION=lz4 \
  -e PRUNE=1 \
  -e KEEP_DAILY=3 \
  -e KEEP_WEEKLY=2 \
  -e KEEP_MONTHLY=1 \
  -e NOTIFICATION_HOOK_URL='https://<rocketchat_url>/hooks/<api_key>' \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  -v /raid/plex.backup:/borg_repo \
  -v /dockers/plex/config:/borg_data/plex/config:ro \
  --security-opt label:disable \
  --name borg-backup2-${ARCHIVE_PREFIX} \
  causalityloop/borgbackup2
```
Backup docker volumes to remote location (Borg must be running in server mode in that remote location):
```
ARCHIVE_PREFIX='wordpress'
docker run \
  -e BORG_REPO='user@hostname:/path/to/repo' \
  -e ARCHIVE=${ARCHIVE_PREFIX}_$(date +%Y-%m-%d_%H.%M.%S) \
  -e BORG_PASSPHRASE=my-secret-pw \
  -e COMPRESSION=lz4 \
  -e PRUNE=1 \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  -v mariadb-data:/borg_data/mariadb:ro \
  -v wordpress-data:/borg_data/wordpress:ro \
  --name borg-backup2-${ARCHIVE_PREFIX} \
  causalityloop/borgbackup2
```

Using sshfs (in case when the Borg is not installed on the remote location):
```
ARCHIVE_PREFIX='wordpress'
docker run \
  -e SSHFS='user@hostname:/path/to/repo' \
  -e SSHFS_PASSWORD=my-ssh-password \
  -e BORG_PASSPHRASE=my-secret-pw \
  -e COMPRESSION=lz4 \
  -e PRUNE=1 \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  -v mariadb-data:/borg_data/mariadb:ro \
  -v wordpress-data:/borg_data/wordpress:ro \
  --cap-add SYS_ADMIN --device /dev/fuse --security-opt label:disable \
  --name borg-backup2-${ARCHIVE_PREFIX} \
  causalityloop/borgbackup2
```

Using sshfs with ssh key authentication:
```
ARCHIVE_PREFIX='wordpress'
docker run \
  -e SSHFS='user@hostname:/path/to/repo' \
  -e SSHFS_IDENTITY_FILE=/root/ssh-key/key \
  -e SSHFS_GEN_IDENTITY_FILE=1 \
  -e BORG_PASSPHRASE=my-secret-pw \
  -e COMPRESSION=lz4 \
  -e PRUNE=1 \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  -v borg-ssh-key:/root/ssh-key \
  -v mariadb-data:/borg_data/mariadb:ro \
  -v wordpress-data:/borg_data/wordpress:ro \
  --cap-add SYS_ADMIN --device /dev/fuse --security-opt label:disable \
  --name borg-backup2-${ARCHIVE_PREFIX} \
  causalityloop/borgbackup2
```

Restoring files from specific day to folder on host:
```
ARCHIVE_PREFIX='wordpress'
docker run \
  -e BORG_REPO='user@hostname:/path/to/repo' \
  -e ARCHIVE="${ARCHIVE_PREFIX}-2016-05-25" \
  -e BORG_PASSPHRASE=my-secret-pw \
  -e EXTRACT_TO=/borg/restore \
  -e EXTRACT_WHAT=only/this/file \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  -v /opt/restore:/borg/restore \
  --security-opt label:disable \
  --name borg-backup-${ARCHIVE_PREFIX} \
  causalityloop/borgbackup2
```

Running custom borg command to show snapshots:
```
docker run \
  -e BORG_PARAMS='list' \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  --name borg-backup \
  causalityloop/borgbackup2
```

Another custom command to delete all snapshots in a repo. As before, `/borg_repo` is the fixed location, within the container, where borg expects the repo. Also, `BORG_DELETE_I_KNOW_WHAT_I_AM_DOING` allows us to disable the prompt to allow for use in automation:
```
docker run \
  -e BORG_PARAMS='delete /borg_repo' \
  -e BORG_DELETE_I_KNOW_WHAT_I_AM_DOING='YES' \
  -v borg-config:/root/.config/borg \
  -v borg-cache:/root/.cache/borg \
  --name borg-backup \
  causalityloop/borgbackup2
```

## Environment variables

Description of all accepted environment variables follows.

### Core variables

**ARCHIVE** - archive parameter for Borg repository. If empty, defaults to `"${HOSTNAME}_$(date +%Y-%m-%d)"`. For more info see [Borg documentation](https://borgbackup.readthedocs.io/en/stable/usage.html)

**EXCLUDE** - paths/patterns to exclude from backup. Paths must be separated by `;`. For example: `-e EXCLUDE='/my path/one;/path two;*.tmp'`

**BORG_PARAMS** - run custom borg command inside of the container. ie execute `borg <value_of_BORG_PARAMS>` and exit

**BORG_SKIP_CHECK** - set to `1` if you want to skip the `borg check` command at the end of the backup

### Compression

**COMPRESSION** - compression to use. Defaults to none. [More info](https://borgbackup.readthedocs.io/en/stable/usage.html#borg-create)

### Encryption

**BORG_PASSPHRASE** - `repokey` mode password to encrypt the backed up data. Defaults to none. Only the `repokey` mode encryption is supported by this Docker image. [More info](https://borgbackup.readthedocs.io/en/stable/usage.html#borg-init)

### Extracting (restoring) files

**EXTRACT_TO** - directory where to extract (restore) borg archive. If this variable is set, default commands are not executed, only the extraction is done. Repo and archive are specified with *BORG_REPO* and *ARCHIVE* variables. [More info](https://borgbackup.readthedocs.io/en/stable/usage.html#borg-extract)

**EXTRACT_WHAT** - subset of files and directories which should be extracted

### Pruning

**PRUNE** - if set, prune the repository after backup. Empty by default. [More info](https://borgbackup.readthedocs.io/en/stable/usage.html#borg-prune)

**PRUNE_PREFIX** - filter data to prune by prefix of the archive. Empty by default - prune all data

**KEEP_DAILY** - keep specified number of daily backups. Defaults to 7

**KEEP_WEEKLY** - keep specified number of weekly backups. Defaults to 4

**KEEP_MONTHLY** - keep specified number of monthly backups. Defaults to 6

### Notifications

**NOTIFICATION_HOOK_URL** - url and api key to send notifications to (rocketchat). This is in the format of `https://<rocketchat_url>/hooks/<api_key>`

### SSHFS

**SSHFS** - sshfs destination in form of `user@host:/path`. When using sshfs, container needs special permissions: `--cap-add SYS_ADMIN --device /dev/fuse` and if using SELinux: `--security-opt label:disable` or apparmor: `--security-opt apparmor:unconfined`

**SSHFS_PASSWORD** - password for ssh authentication

**SSHFS_IDENTITY_FILE** - path to ssh key

**SSHFS_GEN_IDENTITY_FILE** - if set, generates ssh key pair if *SSHFS_IDENTITY_FILE* is set, but the key file doesn't exist. 4096 bits long rsa key will be generated. After generating the key, the public part of the key is printed to stdout and the container stops, so you have the chance to configure the server part before running first backup

