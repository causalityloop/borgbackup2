#!/usr/bin/env bash

set -euo pipefail

# set some defaults
readonly default_archive="${HOSTNAME}_$(date +%Y-%m-%d_%H.%M.%S)"
readonly archive="${ARCHIVE:-$default_archive}"
readonly borg_log='/tmp/borg_report.log'

function echoerr {
    cat <<< "$@" 1>&2;
}

trap cleanup EXIT SIGTERM SIGINT

function cleanup {
    rc=$?
    echo "running cleanup..."

    if [[ -n "${SSHFS:-}" ]]; then
        fusermount -u "$BORG_REPO"
    fi

    set +e # disable errors here as we are on our way out anyways

    send_notification "${NOTIFICATION_HOOK_URL:-}" ${rc} ${borg_log} 

    # exit with original return code
    exit ${rc}
}

function send_notification {
    local __notif_url=$1
    local __retcode=$2
    local __logfile=$3

    if [[ -z "${__notif_url}" ]]; then
        echo "Notifications disabled, skipping..."
        return 0
    fi
    
    if [[ ! -e "${__logfile}" ]]; then
        echo "log file does not exist - skipping notification"
        return 0
    fi

    local __report=$( jq -Rs '.' ${__logfile} )

    local __text_color=$( if [[ ${__retcode} -eq 0 ]]; then echo 'good'; else echo 'danger'; fi )

    # for rocketchat, channel is defined by the url
    read -r -d '' payload <<EOF
    {
        "channel": "",
        "username": "",
        "icon_emoji": ":borg:",
        "attachments": [
            {
                "title": "BorgBackup Report",
                "title_link": "",
                "text_report": ${__report},
                "image_url": "https://github.com/causalityloop/borgbackup2/raw/master/borg-cube.png",
                "color": "${__text_color}"
            }
        ],
        "text": "BorgBackup Report"
    }
EOF

    #echo curl -X POST -H 'Content-Type: application/json' --data '${payload}' "${__notif_url}"
    curl --silent -X POST -H 'Content-Type: application/json' --data "${payload}" "${__notif_url}" > /dev/null
}

BORG_REPO=${BORG_REPO:-/borg_repo} # init to default location

if [[ -n "${SSHFS:-}" ]]; then
    if [[ -n "${SSHFS_IDENTITY_FILE:-}" ]]; then
        if [[ ! -f "$SSHFS_IDENTITY_FILE" ]] && [[ -n "${SSHFS_GEN_IDENTITY_FILE:-}" ]]; then
            ssh-keygen -t rsa -b 4096 -N '' -f "$SSHFS_IDENTITY_FILE"
            cat "${SSHFS_IDENTITY_FILE}.pub"
            exit 0
        fi
        SSHFS_IDENTITY_FILE="-o IdentityFile=${SSHFS_IDENTITY_FILE}"
    else
        SSHFS_IDENTITY_FILE=''
    fi
    if [[ -n "${SSHFS_PASSWORD:-}" ]]; then
        SSHFS_PASSWORD="echo ${SSHFS_PASSWORD} |"
        SSHFS_PASSWORD_OPT='-o password_stdin'
    else
        SSHFS_PASSWORD=''
        SSHFS_PASSWORD_OPT=''
    fi
    mkdir -p /mnt/sshfs
    eval "${SSHFS_PASSWORD} sshfs -o StrictHostKeyChecking=no ${SSHFS} /mnt/sshfs ${SSHFS_IDENTITY_FILE} ${SSHFS_PASSWORD_OPT}"
    BORG_REPO=/mnt/sshfs
fi

export BORG_REPO

##
# CUSTOM COMMANDS - run and exit
##

if [[ -n "${BORG_PARAMS:-}" ]]; then
    borg ${BORG_PARAMS}
    exit 0
fi

##
# END CUSTOM
##

if [[ -z "${BORG_PASSPHRASE:-}" ]]; then
    INIT_ENCRYPTION='--encryption=none'
    # shellcheck disable=2016
    echo 'Not using encryption. If you want to encrypt your files, set the $BORG_PASSPHRASE variable.'
else
    INIT_ENCRYPTION='--encryption=repokey'
fi

##
# EXTRACT ONLY - run and eixt
##
if [[ -n "${EXTRACT_TO:-}" ]]; then
    mkdir -p "${EXTRACT_TO}"
    cd "${EXTRACT_TO}"
    borg extract -v --list --show-rc ::"${archive}" ${EXTRACT_WHAT:-}
    exit 0
fi

# If $BORG_REPO is a local path and the directory is empty, init it
if [[ "${BORG_REPO:0:1}" == '/' ]] && [[ ! "$(ls -A $BORG_REPO)" ]]; then
    borg init -v --show-rc $INIT_ENCRYPTION  |& tee -a ${borg_log}
fi

if [[ -n "${COMPRESSION:-}" ]]; then
    COMPRESSION="--compression=${COMPRESSION}"
else
    COMPRESSION=''
fi

if [ -n "${EXCLUDE:-}" ]; then
    OLD_IFS=$IFS
    IFS=';'

    EXCLUDE_BORG=''
    for i in $EXCLUDE; do
        EXCLUDE_BORG="${EXCLUDE_BORG} --exclude ${i}"
    done

    IFS=$OLD_IFS
else
    EXCLUDE_BORG=''
fi

echo "Creating borg archive (${archive})" |& tee -a ${borg_log}
borg create -v --stats --show-rc $COMPRESSION $EXCLUDE_BORG ::"${archive}" /borg_data |& tee -a ${borg_log}

if [[ -n "${PRUNE:-}" ]]; then
    echo |& tee -a ${borg_log}
    echo "Now running prune..." |& tee -a ${borg_log}
    echo |& tee -a ${borg_log}

    if [[ -n "${PRUNE_PREFIX:-}" ]]; then
        PRUNE_PREFIX="--prefix=${PRUNE_PREFIX}"
    else
        PRUNE_PREFIX=''
    fi

    KEEP_DAILY=${KEEP_DAILY:-7}
    KEEP_WEEKLY=${KEEP_WEEKLY:-4}
    KEEP_MONTHLY=${KEEP_MONTHLY:-6}

    echo "borg prune -v --stats --show-rc ${PRUNE_PREFIX} --keep-daily=${KEEP_DAILY} --keep-weekly=${KEEP_WEEKLY} --keep-monthly=${KEEP_MONTHLY}" |& tee -a ${borg_log}
    borg prune -v --stats --show-rc ${PRUNE_PREFIX} --keep-daily="${KEEP_DAILY}" --keep-weekly="${KEEP_WEEKLY}" --keep-monthly="${KEEP_MONTHLY}" |& tee -a ${borg_log}

fi

if [[ "${BORG_SKIP_CHECK:-}" != '1' ]] && [[ "${BORG_SKIP_CHECK:-}" != "true" ]]; then
    echo |& tee -a ${borg_log}
    echo "Running borg check..." |& tee -a ${borg_log}
    borg check -v --show-rc |& tee -a ${borg_log}
fi
