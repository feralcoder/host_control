#!/bin/bash



ilo_power_get_state () {
  local HOST=$1
  local ILO_IP=`getent ahosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local ILO_COMMAND="power"
  local SUCCESS_GREP="server power is currently: \(On\|Off\)"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_power_get_state "$SUCCESS_GREP"`
  ILO_COMMAND_STATUS=$?
  local STATE=`echo "$OUTPUT" | grep -i "server power is currently" | awk -F':' '{print $3}' | tr '\r' ' ' | sed -r 's/[^a-zA-Z]*([a-zA-Z]+)[^a-zA-Z]*/\1/g'`

  if [[ $ILO_COMMAND_STATUS == 0 ]]; then
    echo "$HOST is $STATE"
  else
    echo "Problem getting power state of $HOST!" 1>&2
  fi
}

ilo_power_wait_for_off () {
  local HOST=$1

  local COUNT INTERVAL
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=12
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
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=12
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
  local ILO_IP=`getent ahosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local COUNT INTERVAL
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=12
  [[ "$3" != "" ]] && INTERVAL=$3 || INTERVAL=10

  echo "Powering off $HOST (soft)..."
  local ILO_COMMAND="power off"
  local SUCCESS_GREP="\(power off\|Server power already \(off.\|Off\)\)"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_power_off "$SUCCESS_GREP"`

  if [[ $? == 0 ]]; then
    echo "ILO power off delivered to $HOST." 1>&2
  else
    echo "Failed to send ILO power off command to $HOST." 1>&2
    echo "Going straight for IPMI chassis control." 1>&2
    for IPMI_TRY in `seq 1 $IPMI_TRIES`; do
      OUTPUT=$(ipmitool -I lanplus -H $ILO_IP -U stack -f ilo_pass chassis power off)
      if [[ $(echo "$OUTPUT" | grep -i 'Down.Off') == "" ]]; then
        echo "Try #$IPMI_TRY to power off $HOST failed to send!" 1>&2
        [[ $IPMI_TRY < $IPMI_TRIES ]] && {
          echo "Trying again in $INTERVAL seconds." 1>&2
          sleep $INTERVAL
        }
      else
        echo "$HOST is powered off via chassis control."
        return 0
      fi
    done
    echo "FAILED to power off $HOST!"
    return 1
  fi


  # ILO COMMAND DELIVERED - WAIT, THEN GET MORE AGGRESSIVE IF NEEDED
  if ( ilo_power_wait_for_off $HOST $COUNT $INTERVAL ) ; then
    echo "$HOST is powered off."
  else
    echo "$HOST did not power off.  Time to hard reset!" 1<&2
    ILO_COMMAND="power off hard"
    local SUCCESS_GREP="\(power off\|Server power already \(off\|Off\)\)"
    OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_power_off`
    [[ $? == 0 ]] && {
      echo "ILO hard power off delivered to $HOST." 1>&2
    }

    if ( ilo_power_wait_for_off $HOST $COUNT $INTERVAL ) ; then
      echo "$HOST is powered off hard."
    else
      echo "$HOST did not hard power off.  Time to use ipmi chassis control!" 1>&2
      for IPMI_TRY in `seq 1 $IPMI_TRIES`; do
        OUTPUT=$(ipmitool -I lanplus -H $ILO_IP -U stack -f ilo_pass chassis power off)
        if [[ $(echo "$OUTPUT" | grep -i 'Down.Off') == "" ]]; then
          echo "FAILED to power off $HOST!"
          return 1
        else
          echo "$HOST is powered off via chassis control."
        fi
      done
    fi
  fi
}


ilo_power_on () {
  local HOST=$1 COUNT
  local ILO_IP=`getent ahosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local COUNT INTERVAL
  [[ "$2" != "" ]] && COUNT=$2 || COUNT=12
  [[ "$3" != "" ]] && INTERVAL=$3 || INTERVAL=10

  local ILO_COMMAND="power on"
  local SUCCESS_GREP="\(power on\|Server power already \(on\|On\)\)"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_power_on "$SUCCESS_GREP"`
  [[ $? == 0 ]] && {
    echo "ILO power on delivered to $HOST." 1>&2
  } || {
    echo "Problem sending power on to $HOST" 1>&2
  }

  if ( ilo_power_wait_for_on $HOST $COUNT $INTERVAL ) ; then
    echo "$HOST is powered on".
  else
    echo "$HOST did not power on via ILO command.  Turning on via ipmi chassis power on." 1>&2
    local IPMI_TRY IPMI_TRIES=2
    for IPMI_TRY in `seq 1 $IPMI_TRIES`; do
      OUTPUT=$(ipmitool -I lanplus -H $ILO_IP -U stack -f ilo_pass chassis power on)
      if [[ $(echo "$OUTPUT" | grep -i 'Up.On') == "" ]]; then
        echo "Try #$IPMI_TRY to power on $HOST failed to send." 1>&2
        [[ $IPMI_TRY < $IPMI_TRIES ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
      else
        echo "$HOST is powered on via chassis control."
        return 0
      fi
      echo "FAILED to power on $HOST!"
      return 1
    done
  fi
}

ilo_power_cycle () {
  local HOST=$1
  ilo_power_off $HOST
  ilo_power_on $HOST
}

ilo_power_off_these_hosts () {
  local HOSTS=$1
  local PIDS="" HOST

  if [[ $UNSAFE == "" ]]; then
    HOSTS=$(group_logic_remove_self "$HOSTS")
  fi

  local RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $?"
        fi
      done
    else
      ilo_power_off $HOST &
      PIDS="$PIDS:$!"
      echo "Started Power Off for $HOST: $!"
    fi
  done
}

ilo_power_on_these_hosts () {
  local HOSTS=$1
  local PIDS="" HOST RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $?"
        fi
      done
    else
      ilo_power_on $HOST &
      PIDS="$PIDS:$!"
      echo "Started Power On for $HOST: $!"
    fi
  done
}

ilo_power_cycle_these_hosts () {
  local HOSTS=$1

  if [[ $UNSAFE == "" ]]; then
    HOSTS=$(group_logic_remove_self "$HOSTS")
  fi

  local PIDS="" HOST RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $?"
        fi
      done
    else
      ilo_power_cycle $HOST &
      PIDS="$PIDS:$!"
      echo "Started Power Cycle for $HOST: $!"
    fi
  done
}

ilo_power_get_state_these_hosts () {
  local HOSTS=$1
  local PIDS="" HOST RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $?"
        fi
      done
    else
      ilo_power_get_state $HOST &
      PIDS="$PIDS:$!"
      echo "Getting power state for $HOST: $!"
    fi
  done
}
