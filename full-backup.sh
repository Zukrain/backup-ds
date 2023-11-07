#!/bin/bash
set -eu

## Определеение типа бекапа full или incremental
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
declare -r REMOTE_SERVER="sftp -i ${PRIV_KEY} ${LOGIN}@storage.${LOGIN}.na4u.ru:"
declare -r BACKUP_DIR="/${LOGIN}/backup"

declare -r DAYS="$(( RANDOM % 3 + 7 ))"
declare -r TEMP_DIR="$(mktemp -d /tmp/DS.d.XXXXXXXX)"
trap "rm -rf $TEMP_DIR" 0

[[ "$(echo "ls -1 $BACKUP_DIR" | $REMOTE_SERVER 2>/dev/null | grep -c 'full.tar.lzo.split_aa')" -ne 0 ]] || {
    exit 0
}

echo "ls -l $BACKUP_DIR" | $REMOTE_SERVER 2>/dev/null | awk '{print $9 "\t" $5}' | grep '[0-9]' | sort | csplit -zs --prefix="$TEMP_DIR/xx" - '/.full.tar.lzo.split_.*/' '{*}'

[[ "$(find "$TEMP_DIR" -name xx\* | wc -l)" -ne 0 ]] || exit 0

declare -r FILES="$(find "$TEMP_DIR" -name xx\* | sort | tail -n1)"

[[ $(wc -l "$FILES" | cut -d' ' -f1) -ge $DAYS ]] && exit 0

declare -r FULLSIZE="$(awk -F'\t' 'BEGIN{print 0}/full\.tar\.lzo\.split_ \t/{print $NF}' "$FILES" | paste -sd+ | bc)"
declare -r INCRSIZE="$(awk -F'\t' 'BEGIN{print 0}/incremental\.tar\.lzo\.split_ \t/{print $NF}' "$FILES" | paste -sd+ | bc)"

[[ "$INCRSIZE" -gt "$((FULLSIZE/2))" ]] || exit 10
