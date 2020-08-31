#!/usr/bin/env bash

# auth
SSH_HOST='remote_server'
SSH_PORT=22
SSH_USER=''
SSH_KEYFILE=''

# local
CMD_PPPD='/usr/sbin/pppd'
CMD_SSH='/usr/bin/ssh'
LOCAL_IFNAME=''
LOCAL_VPN_IP='10.255.0.102'
CHECK_INTERVAL=60

# remote
REMOTE_IFNAME=''
REMOTE_VPN_IP='10.255.0.101'
VPNN=100

# auto set a ifname if it is not assigned
[ -z $LOCAL_IFNAME ] && LOCAL_IFNAME="to_"${SSH_HOST}
[ -z $REMOTE_IFNAME ] && REMOTE_IFNAME="to_"$(hostname)

PID_FILE="/tmp/"$(basename $0)_${LOCAL_IFNAME}


connect()
{
    if [ -z "$(ps -ef | egrep ${REMOTE_VPN_IP}:${LOCAL_VPN_IP} | grep -v grep)" ]
    then
        sudo -E ${CMD_PPPD} updetach noauth silent nodeflate ifname $LOCAL_IFNAME \
        pty "${CMD_SSH} -o StrictHostKeyChecking=no -i ${SSH_KEYFILE} -p $SSH_PORT ${SSH_USER}@${SSH_HOST} sudo ${CMD_PPPD} nodetach notty noauth ifname ${REMOTE_IFNAME} \
        ipparam vpn ${VPNN} ${REMOTE_VPN_IP}:${LOCAL_VPN_IP}"
    else
        echo "$(date)  Tunnel ${LOCAL_IFNAME} is running"
    fi
}

disconnect()
{
    if [ -n "$(ps -ef | egrep ${REMOTE_VPN_IP}:${LOCAL_VPN_IP} | grep -v grep)" ]
    then
        ps -ef | grep ${REMOTE_VPN_IP}:${LOCAL_VPN_IP} | grep -v grep | awk '{print $2}' | xargs sudo kill
    fi
}


start()
{
    while true
    do
        if [ -f $PID_FILE ]
        then
            [ $(cat ${PID_FILE}) != $$ ] && echo "Pid file $PID_FILE is already exist." && exit 1
            connect
        else
            connect
            echo $$ > $PID_FILE
        fi
        sleep $CHECK_INTERVAL
    done
}

stop()
{
    disconnect
    if [ -f $PID_FILE ]
    then
        cat $PID_FILE | xargs sudo kill
        rm $PID_FILE
    fi
}

[ -z $1 ] && echo "$0 start|stop" || $1