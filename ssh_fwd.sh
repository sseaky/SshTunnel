#!/usr/bin/env bash
# @Author: Seaky
# @Date:   2020/9/2 11:20

# auth
SSH_HOST=''
SSH_PORT=22
SSH_USER=''
SSH_KEYFILE=''
SSH_OPTION="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o TCPKeepAlive=yes -o ControlPersist=no"

# bind
LOCAL_ADDRESS=""
LOCAL_PORT=33062
REMOTE_ADDRESS=""
REMOTE_PORT=3306



check_ps()
{
    ps -ef | grep "$*" | grep -v grep
}

check_lport()
{
    ss -lntp | grep LISTEN | grep $LOCAL_PORT
}

connect()
{
    direct=$([ "$1" = "ltor" ] && echo "-L" || echo "-R" )
    cmd="ssh -N $direct ${LOCAL_ADDRESS}:${LOCAL_PORT}:${REMOTE_ADDRESS}:${REMOTE_PORT} -i ${SSH_KEYFILE} $SSH_OPTION -p $SSH_PORT ${SSH_USER}@${SSH_HOST}"
    if [ -z "$(check_ps $cmd)" ]
    then
        if [ -n "$(check_ps $LOCAL_PORT)" ]
        then
            echo "Error: local port $LOCAL_PORT has been occupied."
            exit 1
        fi
        echo "$(date) Forwarding ${LOCAL_ADDRESS}:${LOCAL_PORT}:${REMOTE_ADDRESS}:${REMOTE_PORT}@${SSH_HOST} start"
        $cmd
    else
        echo "$(date) Forwarding "${LOCAL_ADDRESS}:${LOCAL_PORT}:${REMOTE_ADDRESS}:${REMOTE_PORT}@${SSH_HOST}" is running."
        exit 1
    fi
}

start()
{
    while true
    do
        connect $1
        sleep 5
    done
}

[ -z "$SSH_HOST" ] && echo "fill the arguments first" && exit 1
[ -z $1 ] && echo "$0 ltor|rtol" && exit 1
[ "$1" = "ltor" -o "$1" = "rtol" ] && start $1 || echo "$0 ltor|rtol"