#!/usr/bin/env bash
# @Author: Seaky
# @Date:   2020/9/1 9:30

##########
#        #
# Config #
#        #
##########

SSH_HOST='remote.server'
SSH_PORT=22
SSH_USER=''
SSH_OPTION="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o TCPKeepAlive=yes"
SSH_KEYFILE=''
# paste the content of the private key to $SSH_KEY, if do not want to upload the key to server
SSH_KEY=''

# local
CMD_PPPD='/usr/sbin/pppd'
CMD_SSH='/usr/bin/ssh'
LOCAL_IFNAME=''
LOCAL_VPN_IP='10.220.0.102'

# remote
REMOTE_IFNAME=''
REMOTE_VPN_IP='10.220.0.101'
VPNN=100
REMOTE_NETWORK=''
#REMOTE_NETWORK='1.1.1.1 2.2.2.0/24'    # network via remote vpn, split by space

CHECK_INTERVAL=60
PROMPT_INTERVAL=3600

TEMP_DIR='./tmp'

######
#    #
# Do #
#    #
######

PID_FILE="$TEMP_DIR/$(basename $0)-${LOCAL_IFNAME}.pid"

# auto set a ifname if it is not assigned
[ -z $LOCAL_IFNAME ] && LOCAL_IFNAME="to_"${SSH_HOST}
[ -z $REMOTE_IFNAME ] && REMOTE_IFNAME="to_"$(hostname)

# create tmp folder
[ ! -d "$TEMP_DIR" ] && mkdir $TEMP_DIR
[ ! -d "$TEMP_DIR" ] && echo "Create temp dir $TEMP_DIR fail" && exit 1

# verify ssh key
TEMP_KEY=false
if [ -z "$SSH_KEYFILE" ]
then
        if [ -n "$SSH_KEY" ]
        then
            SSH_KEYFILE="$TEMP_DIR/$(basename $0)-${LOCAL_IFNAME}.tmpkey"
            TEMP_KEY=true
        fi
fi

[ -z "$SSH_KEYFILE" ] && echo "no ssh key given." && exit 1


connect()
{
    if [ -z "$(ps -ef | egrep ${REMOTE_VPN_IP}:${LOCAL_VPN_IP} | grep -v grep)" ]
    then
        if $TEMP_KEY
        then
            echo "Create temporary key file $SSH_KEYFILE"
            # need reset IFS if "\n" in $SSH_KEY, when echo the variable to a file
            IFS=""
            echo $SSH_KEY > $SSH_KEYFILE
            chmod 600 $SSH_KEYFILE
            unset IFS
        fi

        sudo -E ${CMD_PPPD} updetach noauth silent nodeflate ifname $LOCAL_IFNAME \
        pty "${CMD_SSH} ${SSH_OPTION} -i ${SSH_KEYFILE} -p $SSH_PORT ${SSH_USER}@${SSH_HOST} \
            sudo ${CMD_PPPD} nodetach notty noauth ifname ${REMOTE_IFNAME} \
            ipparam vpn ${VPNN} ${REMOTE_VPN_IP}:${LOCAL_VPN_IP}"

        # add route
        [ -n "$REMOTE_NETWORK" ] && for nw in $REMOTE_NETWORK
        do
            cmd="ip route add $nw via $REMOTE_VPN_IP"
            echo $cmd
            sudo $cmd;
        done
    else
        true
    fi
    [ -n "$(ip a show up | grep $LOCAL_VPN_IP)" ] && return 0 || return 1
}

disconnect()
{
    echo "\nStop interface $LOCAL_IFNAME\n"
    # delete route
    [ -n "$REMOTE_NETWORK" ] &&
        for nw in $REMOTE_NETWORK
            do
                [ -n "$(ip route get $nw | grep $REMOTE_VPN_IP)" ] && sudo ip route del $nw via $REMOTE_VPN_IP
            done

    # delete ppp pid
    ppp_pids="$(ps -ef | egrep ${REMOTE_VPN_IP}:${LOCAL_VPN_IP} | grep -v grep | awk '{print $2}')"
    [ -n "$ppp_pids" ] && sudo kill $ppp_pids

    # delete temporary key
    $TEMP_KEY && [ -f $SSH_KEYFILE ] && rm $SSH_KEYFILE

    # delete pid file
    if [ -f $PID_FILE ]
    then
        pid=$(cat $PID_FILE)
        rm $PID_FILE
#        [ -n "$(ps -o pid= -p $pid)" -a $pid -ne $$ ] && sudo kill $pid
        [ -n "$(ps -o pid= -p $pid)" ] && sudo kill $pid
    fi
}


start()
{
    echo "\nStart create ppp over ssh to $REMOTE_IFNAME use $LOCAL_IFNAME\n"
    i=0
    while true
    do
        flag_connected=false
        if [ -f $PID_FILE ]
        then
            [ $(cat ${PID_FILE}) != $$ ] && echo "Pid file $PID_FILE is already exist." && exit 1
            connect && flag_connected=true
        else
            echo $$ > $PID_FILE
            connect && flag_connected=true
        fi
        if $flag_connected
        then
            [ $i -eq 0 ] && echo "$(date)  Tunnel ${LOCAL_IFNAME} is running"
        else
            echo "$(date)  Tunnel ${LOCAL_IFNAME} is fail!"
        fi
        sleep $CHECK_INTERVAL
        i=$((i+$CHECK_INTERVAL))
        [ $i -ge $PROMPT_INTERVAL ] && i=0
    done
}

stop()
{
    disconnect
}

restart()
{
        stop
        start
}

trap ctrl_c INT

ctrl_c()
{
    stop
}

[ -z $1 ] && echo "$0 start|stop|restart" || $1
