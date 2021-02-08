#!/bin/bash

. ilo_common.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh

wait_for_host_down () {
  local HOST=$1 IP=$2
  local ATTEMPTS=3 INTERVAL=10

  local STATE="" INTERVAL=3
  while [[ $STATE != "Off" ]]; do
    STATE=$(get_power_state $HOST $IP | awk '{print $3}')
    for COUNT in `seq 1 3`; do
      [[ $STATE == "Off" ]] && break
      echo "$HOST still powered on, checking again in $INTERVAL seconds..."
      sleep $INTERVAL
      STATE=$(get_power_state $HOST $IP | awk '{print $3}')
    done
  done
  echo "$HOST is powered off."
}
wait_for_host_up () {
  local HOST=$1 IP=$2
  local ATTEMPTS=60 INTERVAL=10

  local OUTPUT
  for i in `seq 1 $ATTEMPTS`; do
    OUTPUT=$(ssh -o ConnectTimeout=6 $IP hostname)
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

wait_for_host_down_these_hosts () {
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
      local IP=`getent hosts $HOST | awk '{print $1}'`
      wait_for_host_down $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come down."
    fi
  done
}
wait_for_host_up_these_hosts () {
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
      local IP=`getent hosts $HOST | awk '{print $1}'`
      wait_for_host_up $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come up."
    fi
  done
}

run_as_user () {
  local USER=$1 COMMAND=$2 HOST=$3 IP=$4

  local OUTPUT CODE
  OUTPUT=$(ssh -o ConnectTimeout=10 -l $USER $IP "$COMMAND")
  CODE=$?
  echo "Output from $HOST:"
  echo "$OUTPUT"
  return $CODE
}
run_as_user_on_these_hosts () {
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
      local IP=`getent hosts $HOST | awk '{print $1}'`
      run_as_user $USER "$COMMAND" $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Running \"$COMMAND\" as $USER on $HOST"
    fi
  done
}

sync_as_user () {
  local USER=$1 SOURCE=$2 DEST=$3 HOST=$4 IP=$5

  OUTPUT=$(rsync -avH $SOURCE $USER@$IP:$DEST)
  echo $SOURCE synced to $HOST:
  echo "$OUTPUT"
}
sync_as_user_to_these_hosts () {
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
      local IP=`getent hosts $HOST | awk '{print $1}'`
      sync_as_user $USER $SOURCE $DEST $HOST $IP
      PIDS="$PIDS:$!"
      echo "Syncing $SOURCE to $HOST"
    fi
  done
}
wait_for_host_up_all_hosts () {
  for_for_host_up_these_hosts $ALL_HOSTS
}
wait_for_host_down_all_hosts () {
  for_for_host_down_these_hosts $ALL_HOSTS
}
sync_as_user_to_all_hosts () {
  local USER=$1 SOURCE=$2 DEST=$3
  sync_as_user_to_these_hosts $USER $SOURCE $DEST "$ALL_HOSTS"
}
run_as_user_on_all_hosts () {
  local USER=$1 COMMAND=$2
  run_as_user_on_these_hosts $USER $COMMAND "$ALL_HOSTS"
}
