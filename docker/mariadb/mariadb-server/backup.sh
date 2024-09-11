#!/usr/bin/env bash

set -eu
set -o pipefail

BACKUP_DIR=/backup/
DEFAULT_MY_CNF="/etc/mysql/my.cnf"
ACTIVE_MY_CNF="/etc/mysql/my_active.cnf"

cd $BACKUP_DIR

# Execute a full backup
backup_full() {
    echo "Taking a full backup"
    LAST_FULL_DATE=$(date +%d-%m-%Y)
    mariabackup \
        --defaults-file=$ACTIVE_MY_CNF \
        --backup \
        --stream=xbstream \
        --parallel=4 \
        --history=$LAST_FULL_DATE | pigz -c -p 4 > \
        $BACKUP_DIR/mysqlbackup-$(date +%d-%m-%Y-%s).qp.xbc.xbs.gz
    echo $LAST_FULL_DATE > $BACKUP_DIR/last_full_date
}

# Execute an incremental backup
backup_incremental() {
    echo "Taking an incremental backup"
    if [ -r $BACKUP_DIR/last_full_date ]; then
        LAST_FULL_DATE=$(cat $BACKUP_DIR/last_full_date)
    fi
    if [ -z $LAST_FULL_DATE ]; then
        LAST_FULL_DATE=$(date +%d-%m-%Y)
    fi
    mariabackup \
        --defaults-file=$ACTIVE_MY_CNF \
        --backup \
        --stream=xbstream \
        --parallel=4 \
        --incremental-history-name=$LAST_FULL_DATE \
        --history=$LAST_FULL_DATE | pigz -c -p 4 > \
        $BACKUP_DIR/incremental-$(date +%H)-mysqlbackup-$(date +%d-%m-%Y-%s).qp.xbc.xbs.gz
}

get_and_set_active_server() {
    HOST="$(grep '^host' $DEFAULT_MY_CNF | awk -F '=' '{print $2}' | xargs)"
    USER="$(grep '^user' $DEFAULT_MY_CNF | awk -F '=' '{print $2}' | xargs)"
    PASS="$(grep '^password' $DEFAULT_MY_CNF | awk -F '=' '{print $2}' | xargs)"

    SELECT='SELECT HOST FROM information_schema.PROCESSLIST WHERE ID = CONNECTION_ID();'
    ACTIVE_HOST=$(getent hosts $(mysql -h $HOST -u ${USER} -p${PASS} -s -N -e "$SELECT" | awk -F ':' '{print $1}') | awk '{print $1}')
    cp $DEFAULT_MY_CNF $ACTIVE_MY_CNF
    sed -i "s/$HOST/$ACTIVE_HOST/g" $ACTIVE_MY_CNF
}


if [ -n $BACKUP_TYPE ]; then
    get_and_set_active_server
    case $BACKUP_TYPE in
        "full")
        backup_full
        ;;
        "incremental")
        backup_incremental
        ;;
        *)
        echo "Only full or incremental options are supported."
        exit 1
        ;;
    esac
else
    echo "You need to specify either full or incremental backup options."
    exit 1
fi
