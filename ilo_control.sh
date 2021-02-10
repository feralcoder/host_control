#!/bin/bash

ilo_control_get_ilo_hostkey () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
  ssh-keygen -R $ILO_IP
  ssh-keyscan -T 30 $ILO_IP >> ~/.ssh/known_hosts
  ( grep "$ILO_IP" ~/.ssh/known_hosts ) || {
    echo "Failed to retrieve ipmi host key for $HOST!"
    return 1
  }
}

ilo_control_get_ilo_hostkey_these_hosts () {
  local PIDS="" HOST ILO_IP
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      ilo_control_get_ilo_hostkey $HOST $ILO_IP &
      PIDS="$PIDS:$!"
      echo "Getting host key for $HOST: $!"
    fi
  done
}
