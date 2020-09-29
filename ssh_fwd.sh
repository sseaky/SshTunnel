#!/usr/bin/env bash
# @Author: Seaky
# @Date:   2020/9/2 11:20

##########
#        #
# Config #
#        #
##########

SSH_HOST=''
SSH_PORT=22
SSH_USER=''
SSH_KEYFILE=''
# add content of private key to $SSH_KEY for skipping duplicate private key to server
SSH_KEY=''

# bind
LOCAL_ADDRESS=""
LOCAL_PORT=33061
REMOTE_ADDRESS=""
REMOTE_PORT=3306

TEMP_DIR='./tmp'


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

FIN=false

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
    ps -ef | grep "$*" | grep -v grep
}

connect()
{
    [ "$1" = "ltor" -a -n "$(lsof -i@$LOCAL_ADDRESS:$LOCAL_PORT)" ] && echo "$LOCAL_ADDRESS:$LOCAL_PORT is in use." && exit
    create_tmp_key
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
        $FIN && exit
        sleep 5
    done
}

stop()
{
    FIN=true
    delete_tmp_key
}

ctrl_c()
{

    stop
}

trap ctrl_c INT

[ -z "$SSH_HOST" ] && echo "fill the config block first" && exit 1
[ -z $1 ] && echo "$0 ltor|rtol" && exit 1
[ "$1" = "ltor" -o "$1" = "rtol" ] && start $1 || echo "$0 ltor|rtol"
