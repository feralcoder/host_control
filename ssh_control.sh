#!/bin/bash

. ilo_common.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh

ssh_control_wait_for_host_down () {
  local HOST=$1 ILO_IP=$2
  local ATTEMPTS=3 INTERVAL=10

  local STATE="" INTERVAL=3
  while [[ $STATE != "Off" ]]; do
    STATE=$(ilo_power_get_state $HOST $ILO_IP | awk '{print $3}')
    for COUNT in `seq 1 3`; do
      [[ $STATE == "Off" ]] && break
      echo "$HOST still powered on, checking again in $INTERVAL seconds..."
      sleep $INTERVAL
      STATE=$(ilo_power_get_state $HOST $ILO_IP | awk '{print $3}')
    done
  done
  echo "$HOST is powered off."
}

ssh_control_wait_for_host_up () {
  local HOST=$1 HOST_IP=$2
  local ATTEMPTS=60 INTERVAL=10

  local OUTPUT
  for i in `seq 1 $ATTEMPTS`; do
    OUTPUT=$(ssh -o ConnectTimeout=6 $HOST_IP hostname)
    if [[ $? == 0 ]]; then
      echo "$HOST is UP!"
      return 0
    else
      sleep $INTERVAL
    fi
  done

  echo $HOST DID NOT COME UP!
  return 1
}

ssh_control_wait_for_host_down_these_hosts () {
  local HOST

  local PIDS=""
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      local ILO_IP=`getent hosts ${HOST}-ipmi | awk '{print $1}'`
      ssh_control_wait_for_host_down $HOST $ILO_IP &
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come down."
    fi
  done
}

ssh_control_wait_for_host_up_these_hosts () {
  local HOST

  local PIDS=""
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      local HOST_IP=`getent hosts $HOST | awk '{print $1}'`
      ssh_control_wait_for_host_up $HOST $HOST_IP &
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come up."
    fi
  done
}

ssh_control_run_as_user () {
  local USER=$1 COMMAND=$2 HOST=$3 HOST_IP=$4

  local OUTPUT CODE
  OUTPUT=$(ssh -o ConnectTimeout=10 -l $USER $HOST_IP "$COMMAND")
  CODE=$?
  echo "Output from $HOST:"
  echo "$OUTPUT"
  return $CODE
}

ssh_control_run_as_user_on_these_hosts () {
  local USER=$1 COMMAND=$2 HOSTS=$3
  local HOST

  local PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      local HOST_IP=`getent hosts $HOST | awk '{print $1}'`
      ssh_control_run_as_user $USER "$COMMAND" $HOST $HOST_IP &
      PIDS="$PIDS:$!"
      echo "Running \"$COMMAND\" as $USER on $HOST"
    fi
  done
}

ssh_control_sync_as_user () {
  local USER=$1 SOURCE=$2 DEST=$3 HOST=$4 HOST_IP=$5

  OUTPUT=$(rsync -avH $SOURCE $USER@$HOST_IP:$DEST)
  echo $SOURCE synced to $HOST:
  echo "$OUTPUT"
}

ssh_control_sync_as_user_to_these_hosts () {
  local USER=$1 SOURCE=$2 DEST=$3 HOSTS=$4
  local HOST

  local PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      local HOST_IP=`getent hosts $HOST | awk '{print $1}'`
      ssh_control_sync_as_user $USER $SOURCE $DEST $HOST $HOST_IP
      PIDS="$PIDS:$!"
      echo "Syncing $SOURCE to $HOST"
    fi
  done
}

ssh_control_wait_for_host_up_all_hosts () {
  ssh_control_wait_for_host_up_these_hosts $ALL_HOSTS
}
ssh_control_wait_for_host_down_all_hosts () {
  ssh_control_wait_for_host_down_these_hosts $ALL_HOSTS
}

ssh_control_sync_as_user_to_all_hosts () {
  local USER=$1 SOURCE=$2 DEST=$3
  ssh_control_sync_as_user_to_these_hosts $USER $SOURCE $DEST "$ALL_HOSTS"
}
ssh_control_run_as_user_on_all_hosts () {
  local USER=$1 COMMAND=$2
  ssh_control_run_as_user_on_these_hosts $USER $COMMAND "$ALL_HOSTS"
}
