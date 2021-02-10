#!/bin/bash



ilo_power_get_state () {
  local HOST=$1 IP=$2 STATE
  #STATE=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power" | grep "server power is currently" | awk -F':' '{print $3}' | sed 's/[^a-zA-Z]*\([a-zA-Z]+\)[^a-zA-Z]*/\1/g' )
  STATE=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power" | grep "server power is currently" | awk -F':' '{print $3}' | tr '\r' ' ' | sed -r 's/[^a-zA-Z]*([a-zA-Z]+)[^a-zA-Z]*/\1/g' )
  echo "$HOST is $STATE"
}

ilo_power_wait_for_off () {
  local HOST=$1 IP=$2
  local COUNT INTERVAL
  [[ "$3" != "" ]] && COUNT=$3 || COUNT=5
  [[ "$4" != "" ]] && INTERVAL=$4 || INTERVAL=10

  local ITER STATE
  for ITER in `seq 1 $COUNT`; do
    echo "Checking power state of $HOST..."
    STATE=$(ilo_power_get_state $HOST $IP | awk '{print $3}')
    [[ $STATE == "Off" ]] && return 0
    [[ "$ITER" != "$COUNT" ]] || { echo "$HOST did not power off!"; return 1; }
    echo "$HOST still powered on, waiting $INTERVAL seconds to check again..."
    sleep $INTERVAL
  done
  # We should have returned 0 or 1 already, from within loop...
}

ilo_power_wait_for_on () {
  local HOST=$1 IP=$2
  local COUNT INTERVAL
  [[ "$3" != "" ]] && COUNT=$3 || COUNT=5
  [[ "$4" != "" ]] && INTERVAL=$4 || INTERVAL=10

  local ITER STATE
  for ITER in `seq 1 $COUNT`; do
    echo "Checking power state of $HOST..."
    STATE=$(ilo_power_get_state $HOST $IP | awk '{print $3}')
    [[ $STATE == "On" ]] && return 0
    [[ "$ITER" != "$COUNT" ]] || { echo "$HOST did not power on!"; return 1; }
    echo "$HOST still powered off, waiting $INTERVAL seconds to check again..."
    sleep $INTERVAL
  done
  # We should have returned 0 or 1 already, from within loop...
}

ilo_power_off () {
  local HOST=$1 IP=$2
  local COUNT INTERVAL
  [[ "$3" != "" ]] && COUNT=$3 || COUNT=5
  [[ "$4" != "" ]] && INTERVAL=$4 || INTERVAL=10

  echo "Powering off $HOST (soft)..."
  local OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power off")

  if ( ilo_power_wait_for_off $HOST $IP $COUNT $INTERVAL ) ; then
    echo "$HOST is powered off."
  else
    echo "$HOST did not power off.  Time to hard reset!"
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power off hard")
    if ( ilo_power_wait_for_off $HOST $IP 2 5 ) ; then
      echo "$HOST is powered off hard."
    else
      echo "$HOST did not hard power off.  Time to use ipmi chassis control!"
      OUTPUT=$(ipmitool -I lanplus -H $IP -U stack -f ilo_pass chassis power off)
      if [[ $(echo "$OUTPUT" | grep 'Down.Off') == "" ]]; then
        echo "FAILED to power off $HOST!"
        return 1
      else
        echo "$HOST is powered off via chassis control."
      fi
    fi
  fi
}

ilo_power_on () {
  local HOST=$1 IP=$2 COUNT
  local COUNT INTERVAL
  [[ "$3" != "" ]] && COUNT=$3 || COUNT=5
  [[ "$4" != "" ]] && INTERVAL=$4 || INTERVAL=10

  local OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "power on")
  if ( ilo_power_wait_for_on $HOST $IP $COUNT $INTERVAL ) ; then
    echo "$HOST is powered on".
  else
    echo "$HOST did not power on.  Turning on via ipmi chassis power on."
    OUTPUT=$(ipmitool -I lanplus -H $IP -U stack -f ilo_pass chassis power on)
    if [[ $(echo "$OUTPUT" | grep 'Up.On') == "" ]]; then
      echo "FAILED to power on $HOST!"
      return 1
    else
      echo "$HOST is powered on via chassis control."
    fi
  fi
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
