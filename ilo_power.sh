#!/bin/bash



ilo_power_get_state () {
  local HOST=$1 IP=$2 STATE
  #STATE=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power" | grep "server power is currently" | awk -F':' '{print $3}' | sed 's/[^a-zA-Z]*\([a-zA-Z]+\)[^a-zA-Z]*/\1/g' )
  STATE=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power" | grep "server power is currently" | awk -F':' '{print $3}' | tr '\r' ' ' | sed -r 's/[^a-zA-Z]*([a-zA-Z]+)[^a-zA-Z]*/\1/g' )
  echo "$HOST is $STATE"
}

ilo_power_off () {
  local HOST=$1 IP=$2 COUNT
  local STATE=""
  while [[ $STATE != "Off" ]]; do
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power off")
    for COUNT in `seq 1 3`; do
      sleep 3
      STATE=$(ilo_power_get_state $HOST $IP | awk '{print $3}')
      [[ $STATE == "Off" ]] && break
      echo "$HOST still powered on, checking again..."
    done
  done
  echo "$HOST is powered off."
}

ilo_power_on () {
  local HOST=$1 IP=$2 COUNT
  local STATE=""
  while [[ $STATE != "On" ]]; do
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power on")
    for COUNT in `seq 1 3`; do
      sleep 3
      STATE=$(ilo_power_get_state $HOST $IP | awk '{print $3}')
      [[ $STATE == "On" ]] && break
      echo "$HOST still powered off, checking again..."
    done
  done
  echo "$HOST is powered on."
}

ilo_power_off_these_hosts () {
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
      ilo_power_off $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Started Power Off for $HOST: $!"
    fi
  done
}

ilo_power_on_these_hosts () {
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
      ilo_power_on $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Started Power On for $HOST: $!"
    fi
  done
}

ilo_power_off_all_ilo2_hosts () {
  ilo_power_off_these_hosts $ILO2_HOSTS
}
ilo_power_off_all_ilo4_hosts () {
  ilo_power_off_these_hosts $ILO2_HOSTS
}
ilo_power_off_all_hosts () {
  local PID_ILO2 PID_ILO4
  ilo_power_off_these_hosts $ILO2_HOSTS &
  PID_ILO2="$!"
  echo "Started Power On for ILO2 Servers: $PID_ILO2"
  ilo_power_off_these_hosts $ILO4_HOSTS &
  PID_ILO4="$!"
  echo "Started Power On for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}
ilo_power_on_all_ilo2_hosts () {
  ilo_power_on_these_hosts $ILO2_HOSTS
}
ilo_power_on_all_ilo4_hosts () {
  ilo_power_on_these_hosts $ILO4_HOSTS
}
ilo_power_on_all_hosts () {
  local PID_ILO2 PID_ILO4
  ilo_power_on_these_hosts $ILO2_HOSTS &
  PID_ILO2="$!"
  echo "Started Power On for ILO2 Servers: $PID_ILO2"
  ilo_power_on_these_hosts $ILO4_HOSTS &
  PID_ILO4="$!"
  echo "Started Power On for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}



ilo_power_get_state_these_hosts () {
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
      ilo_power_get_state $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Getting power state for $HOST: $!"
    fi
  done
}
ilo_power_get_state_all_ilo2_hosts () {
  ilo_power_get_state_these_hosts $ILO2_HOSTS
}
ilo_power_get_state_all_ilo4_hosts () {
  ilo_power_get_state_these_hosts $ILO4_HOSTS
}
ilo_power_get_state_all_hosts () {
  echo "Getting Power State For All Hosts."
  ilo_power_get_state_these_hosts $ILO2_HOSTS $ILO4_HOSTS
}
