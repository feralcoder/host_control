#!/bin/bash



ilo_power_get_state () {
  local HOST=$1 STATE
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  STATE=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "power" | grep -i "server power is currently" | awk -F':' '{print $3}' | tr '\r' ' ' | sed -r 's/[^a-zA-Z]*([a-zA-Z]+)[^a-zA-Z]*/\1/g' )
  echo "$HOST is $STATE"
}

ilo_power_wait_for_off () {
  local HOST=$1

  local COUNT INTERVAL
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=5
  [[ "$3" != "" ]] && INTERVAL=$3 || INTERVAL=10

  local ITER STATE
  for ITER in `seq 1 $COUNT`; do
    echo "Checking power state of $HOST..."
    STATE=$(ilo_power_get_state $HOST | awk '{print $3}')
    [[ $STATE == "Off" ]] && return 0
    [[ "$ITER" != "$COUNT" ]] || { echo "$HOST did not power off!"; return 1; }
    echo "$HOST still powered on, waiting $INTERVAL seconds to check again..."
    sleep $INTERVAL
  done
  # We should have returned 0 or 1 already, from within loop...
}

ilo_power_wait_for_on () {
  local HOST=$1

  local COUNT INTERVAL
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=5
  [[ "$3" != "" ]] && INTERVAL=$3 || INTERVAL=10

  local ITER STATE
  for ITER in `seq 1 $COUNT`; do
    echo "Checking power state of $HOST..."
    STATE=$(ilo_power_get_state $HOST | awk '{print $3}')
    [[ $STATE == "On" ]] && return 0
    [[ "$ITER" != "$COUNT" ]] || { echo "$HOST did not power on!"; return 1; }
    echo "$HOST still powered off, waiting $INTERVAL seconds to check again..."
    sleep $INTERVAL
  done
  # We should have returned 0 or 1 already, from within loop...
}

ilo_power_off () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  local COUNT INTERVAL
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=5
  [[ "$3" != "" ]] && INTERVAL=$3 || INTERVAL=10

  local TRIES=3 OUTPUT
  for TRY in `seq 1 $TRIES`; do
    echo "Powering off $HOST (soft)..."
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "power off")
    if ( OUTPUT=`echo $OUTPUT | grep -i 'power off\|powering off\|already off'` ) ; then
      break # ILO COMMAND WAS DELIVERED - BREAK AND CONTINUE WITH WAITS BELOW
    else
      echo "Failed to send ILO power off command."
      if [[ $TRY != $TRIES ]] ; then
        echo "Trying again in 10 seconds."
        sleep 10
      else # ILO COMMANDS FAILED - USE IPMI AND RETURN FROM HERE
        echo "Out of tries, ILO not responsive."
        echo "Going straight for IPMI chassis control."
        OUTPUT=$(ipmitool -I lanplus -H $ILO_IP -U stack -f ilo_pass chassis power off)
        if [[ $(echo "$OUTPUT" | grep -i 'Down.Off') == "" ]]; then
          echo "FAILED to power off $HOST!"
          return 1
        else
          echo "$HOST is powered off via chassis control."
          return 0
        fi
      fi
    fi
  done
    

  # ILO COMMAND DELIVERED - WAIT, THEN GET MORE AGGRESSIVE IF NEEDED
  if ( ilo_power_wait_for_off $HOST $COUNT $INTERVAL ) ; then
    echo "$HOST is powered off."
  else
    echo "$HOST did not power off.  Time to hard reset!"
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "power off hard")
    if ( ilo_power_wait_for_off $HOST 2 5 ) ; then
      echo "$HOST is powered off hard."
    else
      echo "$HOST did not hard power off.  Time to use ipmi chassis control!"
      OUTPUT=$(ipmitool -I lanplus -H $ILO_IP -U stack -f ilo_pass chassis power off)
      if [[ $(echo "$OUTPUT" | grep -i 'Down.Off') == "" ]]; then
        echo "FAILED to power off $HOST!"
        return 1
      else
        echo "$HOST is powered off via chassis control."
      fi
    fi
  fi
}

ilo_power_on () {
  local HOST=$1 COUNT
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  local COUNT INTERVAL
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=5
  [[ "$3" != "" ]] && INTERVAL=$3 || INTERVAL=10

  local OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "power on")
  if ( ilo_power_wait_for_on $HOST $COUNT $INTERVAL ) ; then
    echo "$HOST is powered on".
  else
    echo "$HOST did not power on via ILO command.  Turning on via ipmi chassis power on."
    OUTPUT=$(ipmitool -I lanplus -H $ILO_IP -U stack -f ilo_pass chassis power on)
    if [[ $(echo "$OUTPUT" | grep -i 'Up.On') == "" ]]; then
      echo "FAILED to power on $HOST!"
      return 1
    else
      echo "$HOST is powered on via chassis control."
    fi
  fi
}

ilo_power_off_these_hosts () {
  local PIDS="" HOST 

  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_power_off $HOST &
      PIDS="$PIDS:$!"
      echo "Started Power Off for $HOST: $!"
    fi
  done
}

ilo_power_on_these_hosts () {
  local PIDS="" HOST
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_power_on $HOST &
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
  local PIDS="" HOST
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_power_get_state $HOST &
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
