#!/bin/bash



get_power_state () {
  local HOST=$1 IP=$2 STATE
  #STATE=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power" | grep "server power is currently" | awk -F':' '{print $3}' | sed 's/[^a-zA-Z]*\([a-zA-Z]+\)[^a-zA-Z]*/\1/g' )
  STATE=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power" | grep "server power is currently" | awk -F':' '{print $3}' | tr '\r' ' ' | sed -r 's/[^a-zA-Z]*([a-zA-Z]+)[^a-zA-Z]*/\1/g' )
  echo "$HOST is $STATE"
}

power_off () {
  local HOST=$1 IP=$2 COUNT
  local STATE=""
  while [[ $STATE != "Off" ]]; do
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power off")
    for COUNT in `seq 1 3`; do
      sleep 3
      STATE=$(get_power_state $HOST $IP | awk '{print $3}')
      [[ $STATE == "Off" ]] && break
      echo "$HOST still powered on, checking again..."
    done
  done
  echo "$HOST is powered off."
}

power_on () {
  local HOST=$1 IP=$2 COUNT
  local STATE=""
  while [[ $STATE != "On" ]]; do
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power on")
    for COUNT in `seq 1 3`; do
      sleep 3
      STATE=$(get_power_state $HOST $IP | awk '{print $3}')
      [[ $STATE == "On" ]] && break
      echo "$HOST still powered off, checking again..."
    done
  done
  echo "$HOST is powered on."
}

power_off_these_hosts () {
  local PIDS="" HOST IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      power_off $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Started Power Off for $HOST: $!"
    fi
  done
}

power_on_these_hosts () {
  local PIDS="" HOST IP
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      power_on $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Started Power On for $HOST: $!"
    fi
  done
}

power_off_all_ilo2_hosts () {
  power_off_these_hosts $ILO2_HOSTS
}
power_off_all_ilo4_hosts () {
  power_off_these_hosts $ILO2_HOSTS
}
power_off_all_hosts () {
  local PID_ILO2 PID_ILO4
  power_off_these_hosts $ILO2_HOSTS &
  PID_ILO2="$!"
  echo "Started Power On for ILO2 Servers: $PID_ILO2"
  power_off_these_hosts $ILO4_HOSTS &
  PID_ILO4="$!"
  echo "Started Power On for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}
power_on_all_ilo2_hosts () {
  power_on_these_hosts $ILO2_HOSTS
}
power_on_all_ilo4_hosts () {
  power_on_these_hosts $ILO4_HOSTS
}
power_on_all_hosts () {
  local PID_ILO2 PID_ILO4
  power_on_these_hosts $ILO2_HOSTS &
  PID_ILO2="$!"
  echo "Started Power On for ILO2 Servers: $PID_ILO2"
  power_on_these_hosts $ILO4_HOSTS &
  PID_ILO4="$!"
  echo "Started Power On for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}



get_power_state_these_hosts () {
  local PIDS="" HOST IP
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      get_power_state $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Getting power state for $HOST: $!"
    fi
  done
}
get_power_state_all_ilo2_hosts () {
  get_power_state_these_hosts $ILO2_HOSTS
}
get_power_state_all_ilo4_hosts () {
  get_power_state_these_hosts $ILO4_HOSTS
}
get_power_state_all_hosts () {
  echo "Getting Power State For All Hosts."
  get_power_state_these_hosts $ILO2_HOSTS $ILO4_HOSTS
}
