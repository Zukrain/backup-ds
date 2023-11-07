#!/bin/bash
set -eu

## Удаление старых бекапов из DataStorage
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

declare -r LOGIN="$1"
declare -r DAYS="$2"

declare -r PRIV_KEY='/root/.ssh/id_rsa_ds'
declare -r REMOTE_SERVER="sftp -i ${PRIV_KEY} ${LOGIN}@storage.${LOGIN}.na4u.ru:"
declare -r BACKUP_DIR="/${LOGIN}/backup"

declare -r MAX_DATE="$(date +%Y%m%d -d "-$DAYS days")"
declare -r TEMP_DIR="$(mktemp -d /tmp/DS.d.XXXXXXXX)"
trap "rm -rf $TEMP_DIR" 0

# Проверка, что есть несколько полных бекапов
[[ "$(echo "ls -1 $BACKUP_DIR" | $REMOTE_SERVER 2>/dev/null | grep -c 'full.tar.lzo.split_aa')" -ne 1 ]] || {
    echo 'Warning: last full-backup'
    exit 0
}

declare -r LIST="$(echo "ls -1 $BACKUP_DIR" | $REMOTE_SERVER 2>/dev/null)"
echo "$LIST" | sed -e 's/[a-zA-Z0-9\/]*-//' -e 's/-[a-zA-Z0-9\/\.\_]*//' | awk "{ if (\$0 <= $MAX_DATE) print \$1 }" | uniq -c | awk '{print $2}' > "${TEMP_DIR}/date"

touch "${TEMP_DIR}/files"
cat "${TEMP_DIR}/date" | while read -r DATE; do
    echo "$LIST" | grep "$DATE" >> "${TEMP_DIR}/files"
done

declare -ri COUNT="$(wc -l "${TEMP_DIR}/files" | cut -d' ' -f1)"

if [[ "$COUNT" -gt 0 ]]; then
    let FULL=$(echo "$LIST" | grep -c '.full.tar.lzo.split_.*$')-$(grep -c '.full.tar.lzo.split_.*$' "${TEMP_DIR}/files")
    [[ "$FULL" -gt 1 ]] || exit 10

    cat "${TEMP_DIR}/files" | while read -r FILE; do
        echo "rm $FILE" | $REMOTE_SERVER 1>/dev/null 2>&1
    done
fi
