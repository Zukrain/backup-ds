#!/bin/bash
set -eu

## Создание необходимого окружения для бекапа в DataStorage
## Команду запускать один раз при первоначальной настройке сервера
##
## Параметры:
#~ Login    Имя пользователя услуги DataStorage

print_usage() {
    cat >&2 <<EOF
Usage:

    ${0##*/} LOGIN

EOF
    exit 2
}

(( $# == 1 )) || {
    print_usage
}

declare -r LOGIN="$1"

declare -r PRIV_KEY='/root/.ssh/id_rsa_ds'

declare -r TMP_FILE="$(mktemp /tmp/DS.XXXXXXXX)"
trap "rm -f $TMP_FILE" 0

mkdir -p /root/.ds-backup/tmp
mkdir /root/.ds-backup/split_files
touch /root/.ds-backup/backup.list /root/.ds-backup/excludes.list

echo "mkdir /${LOGIN}/backup" | sftp -i "$PRIV_KEY" "${LOGIN}"@storage."${LOGIN}".na4u.ru: 1>/dev/null 2>"$TMP_FILE"
grep -iq 'Failure' "$TMP_FILE" && {
    echo "ERROR: couldn't create directory '/${LOGIN}/backup' in the DataStorage"
    exit 1
} || :

exit 0
