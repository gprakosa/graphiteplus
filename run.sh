#!/bin/bash

set -e

shutdown(){
    echo "Shutting Down"
    ls /etc/service | SHELL=/bin/sh parallel --no-notice sv force-stop {}
    if [ -e /proc/$RUNSVDIR ]; then
	kill -HUP $RUNSVDIR
	wait $RUNSVDIR
    fi
    sleep 1
    ORPHANS=`ps -eo pid | grep -v PID  | tr -d ' ' | grep -v '^1$'`
    SHELL=/bin/bash parallel --no-notice 'timeout 5 /bin/bash -c "kill {} && wait {}" || kill -9 {}' ::: $ORPHANS 2> /dev/null
    exit
}

startup(){
    /etc/init.d/grafana-server start
    exec runsvdir -P /etc/service &
    RUNSVDIR=$!
    echo "Started runsvdir, PID is $RUNSVDIR"

    trap shutdown SIGTERM SIGHUP SIGINT
    wait $RUNSVDIR
shutdown
}

main(){
   startup
}

main