#!/usr/bin/env bash
# @Author: Seaky
# @Date:   2020/9/2 11:20

##########
#        #
# Config #
#        #
##########

SSH_HOST='remote.server'
SSH_PORT=22
SSH_USER=''
SSH_OPTION="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o TCPKeepAlive=yes -o ControlPersist=no -o ControlMaster=no -o ControlPath=no"
SSH_KEYFILE=''
# add content of private key to $SSH_KEY for skipping duplicate private key to server
SSH_KEY=''

# bind
LOCAL_ADDRESS="127.0.0.1"
LOCAL_PORT=6033
REMOTE_ADDRESS="127.0.0.1"
REMOTE_PORT=3306

TEMP_DIR='./tmp'

RETRY_DELAY=5


######
#    #
# Do #
#    #
######

# create tmp folder
[ ! -d "$TEMP_DIR" ] && mkdir $TEMP_DIR
[ ! -d "$TEMP_DIR" ] && echo "Create temp dir $TEMP_DIR fail" && exit 1

# verify ssh key
TEMP_KEY=false
if [ -z "$SSH_KEYFILE" ]
then
        if [ -n "$SSH_KEY" ]
        then
            SSH_KEYFILE="$TEMP_DIR/$(basename $0).tmpkey"
            TEMP_KEY=true
        fi
fi
[ -z "$SSH_KEYFILE" ] && echo "no ssh key given." && exit 1

create_tmp_key()
{
    if $TEMP_KEY
    then
        echo "Create temporary key file $SSH_KEYFILE"
        # need reset IFS if "\n" in $SSH_KEY, when echo the variable to a file
        IFS=""
        echo $SSH_KEY > $SSH_KEYFILE
        chmod 600 $SSH_KEYFILE
        unset IFS
    fi
}

delete_tmp_key()
{
    $TEMP_KEY && [ -f $SSH_KEYFILE ] && rm $SSH_KEYFILE
}

check_ps()
{
    ps -ef  | grep -v grep | grep -- "$*"
}

forward_local_flow_to_remote_service()
{
    [ -n "$(lsof -i@$LOCAL_ADDRESS:$LOCAL_PORT)" ] && echo "Error: $LOCAL_ADDRESS:$LOCAL_PORT is in use." && stop
    cmd="ssh -N -L ${LOCAL_ADDRESS}:${LOCAL_PORT}:${REMOTE_ADDRESS}:${REMOTE_PORT} -i ${SSH_KEYFILE} $SSH_OPTION -p $SSH_PORT ${SSH_USER}@${SSH_HOST}"
    [ -n "$(check_ps $cmd)" ] && echo "Error: Forwarding is exist" && stop
    create_tmp_key
    echo "Access of local ${LOCAL_ADDRESS}:${LOCAL_PORT} will be forward to remote service ${REMOTE_ADDRESS}:${REMOTE_PORT}"
    $cmd
}

forward_remote_flow_to_local_service()
{
    cmd="ssh -N -R ${REMOTE_ADDRESS}:${REMOTE_PORT}:${LOCAL_ADDRESS}:${LOCAL_PORT} -i ${SSH_KEYFILE} $SSH_OPTION -p $SSH_PORT ${SSH_USER}@${SSH_HOST}"
    [ -n "$(check_ps $cmd)" ] && echo "Error: Forwarding is exist" && stop
    echo "Access of remote ${REMOTE_ADDRESS}:${REMOTE_PORT} will be forward to local service ${LOCAL_ADDRESS}:${LOCAL_PORT}"
    create_tmp_key
    $cmd
}

connect()
{
    if [ "$1" = "ltor" ]
    then
        forward_local_flow_to_remote_service
    elif [ "$1" = "rtol" ]
    then
        forward_remote_flow_to_local_service
    fi
}

start()
{
    while true
    do
        connect $1
        sleep $RETRY_DELAY
    done
}

stop()
{
    delete_tmp_key
    exit
}

ctrl_c()
{
    stop
}

trap ctrl_c INT

[ -z "$SSH_HOST" ] && echo "fill the config block first" && exit 1
[ -z $1 ] && echo "$0 ltor|rtol" && exit 1
[ "$1" = "ltor" -o "$1" = "rtol" ] && start $1 || echo "$0 ltor|rtol"
