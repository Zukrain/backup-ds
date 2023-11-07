#!/bin/bash
set -eu

## Создание бекапа в DataStorage
## Резервная копия создается с помощью tar и выгружается со stdin в хранилище пользователя
##
## Параметры:
#~ Login    Имя пользователя услуги DataStorage
#~ Days     Кол-во дней хранения бекапов

print_usage() {
    cat >&2 <<EOF
Usage:

    ${0##*/} LOGIN DAYS

EOF
    exit 2
}

(( $# == 2 )) || {
    print_usage
}

declare -r PATH="/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin"

declare -r LOGIN="$1"
declare -r DAYS="$2"
declare -r PRIV_KEY='/root/.ssh/id_rsa_ds'
declare -r REMOTE_SERVER="sftp -i ${PRIV_KEY} ${LOGIN}@storage.${LOGIN}.na4u.ru:"

declare -r BACKUP_DIR="/${LOGIN}/backup"
declare -r BACKUP_TMP="/root/.ds-backup/tmp"
declare -r BACKUP_FILE="/root/.ds-backup/backup.list"
declare -r EXCLUDE_FILE="/root/.ds-backup/excludes.list"
declare -r SPLIT_DIR='/root/.ds-backup/split_files'

declare -r TODAY="$(date +%Y%m%d)"

declare PID="$$"
declare PREFIX="worker-backup[$PID]"

log() {
    echo "$PREFIX: $@" >&2
}

error() {
    echo "$PREFIX: ERROR: $@" >&2
}

fatal() {
    echo "$PREFIX: FATAL: $@" >&2
    exit 1
}

## Очищаем бекапы старее DAYS дней
clean-backup.sh "$LOGIN" "$DAYS"

## Проверка наличия бэкапа за текущий день (если есть -- пропускаем)
if [[ $(echo "ls -1 $BACKUP_DIR" | $REMOTE_SERVER 2>/dev/null | grep -E "${TODAY}-(full|incremental)\.tar\.lzo\.split_.*$" | wc -l) -eq 0 ]]; then
    
    export BACKUP_TYPE="full"
    declare -i ERR='0'

    full-backup.sh "$LOGIN" || ERR="$?"

    case $ERR in
    0)
        export BACKUP_TYPE='full'
    ;;
    10)
        export BACKUP_TYPE='incremental'
    ;;
    *)
        error "determining backup type, do full backup"
    ;;
    esac

    declare -r LOCKFILE="${BACKUP_TMP}/${LOGIN}.lock"

    ( flock -n 9 || exit 9

    log "Begin backup for ${LOGIN}, type: ${BACKUP_TYPE}"
    declare -r BACKUPFILENAME="${LOGIN}-${TODAY}-${BACKUP_TYPE}.tar.lzo"
    export INCLIST="${BACKUP_TMP}/${LOGIN}.tar_incremental"

    declare -r TMP_FILE="$(mktemp /tmp/DS.XXXXXXXX)"
    trap "rm -f $TMP_FILE" 0 1

    [[ "$BACKUP_TYPE" = "full" ]] && rm -f "$INCLIST"
    ERR=0

    cd "$SPLIT_DIR"

    tar -c --listed-incremental=$INCLIST \
    --use-compress-program=lzop \
    --no-check-device \
    --warning=none \
    --ignore-failed-read \
    --exclude-from=$EXCLUDE_FILE $(cat $BACKUP_FILE) | split -C 2G - ${BACKUPFILENAME}.split_

    for SPLIT_FILE in $(find -name '*tar.lzo.split_*'); do
        echo "put ${SPLIT_FILE}" | ${REMOTE_SERVER}${BACKUP_DIR##*/}/ 1>/dev/null 2>>"$TMP_FILE"
        rm -f "$SPLIT_FILE"
    done

    [[ "$(grep -v "Connected to storage.${LOGIN}.na4u.ru" $TMP_FILE | wc -l)" -eq 0 ]] && {
        log "Backup for $LOGIN is done"
    } || {
        fatal "$BACKUP_TYPE backup for $LOGIN is failed: $(cat $TMP_FILE)"
    }

    exit 0

    ) 9>"$LOCKFILE"

    [[ $? -gt 0 ]] && {
        fatal "can't lock new backup for $LOGIN -- skip it"
    } || {
        rm -f "$LOCKFILE"
    }
else
    log "Backup $LOGIN already made"
fi

exit 0
