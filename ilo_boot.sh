#!/bin/bash

DEFAULT_BOOT_ORDER="1:5:2:3:4"


ilo_boot_get_order () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local BOOTS BOOTDEV
  BOOTS=$( echo $(for BOOTDEV in `seq 1 5`; do
    local ILO_COMMAND="show /system1/bootconfig1/bootsource$BOOTDEV"
    local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_boot_get_order`
    ILO_COMMAND_STATUS=$?
    
    if [[ $ILO_COMMAND_STATUS == 0 ]]; then
      local ORDER=$(echo "$OUTPUT" | grep bootorder | awk -F'=' '{print $2}' | sed  's/.*\([0-9]\).*/\1/g')
      echo $ORDER
      continue
    else
      echo "Problem getting bootorder for bootsource$BOOTDEV on $HOST" 1>&2
    fi
  done) | sed 's/ /:/g' )
  echo $HOST:$BOOTS
}

ilo_boot_set_order () {
  local HOST ILO_IP BOOT_ORDER
  read HOST BOOT_ORDER <<< `echo $1 | sed 's/:/ /g' | awk '{print $1 " " $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local -a BOOTS=()
  BOOTS=(${BOOT_ORDER//:/ })
  [[ $DEBUG == "" ]] || {
    echo "DEBUG: in ilo_boot_set_order: BOOTS SPLIT FROM $BOOT_ORDER:" 1>&2
    echo "DEBUG: in ilo_boot_set_order: ${BOOTS[1]} ${BOOTS[2]} ${BOOTS[3]} ${BOOTS[4]} ${BOOTS[5]}" 1>&2
  }


  local BOOTPOSITION DEVICE OUTPUT IN_POST COMPLETED STATUS_TAG ERROR_TAG
  for BOOTPOSITION in `seq 1 5`; do for DEVICE in `seq 1 5`; do
    if [[ ${BOOTS[$DEVICE]} == $BOOTPOSITION ]]; then

      local ILO_COMMAND="set /system1/bootconfig1/bootsource$DEVICE bootorder=$BOOTPOSITION"
      local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_boot_set_order`
      ILO_COMMAND_STATUS=$?
      
      if [[ $ILO_COMMAND_STATUS == 0 ]]; then
        echo "Done setting $HOST BootDev:$DEVICE=$BOOTPOSITION"
      else
        echo "ERROR Condition encountered setting bootsource$BOOTPOSITION on $HOST!!!"
      fi
    fi
  done; done
}


ilo_boot_set_first_boot () {
  local BOOTDEV=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local ILO_COMMAND="set /system1/bootconfig1/bootsource$BOOTDEV bootorder=1"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_boot_set_first_boot`
  ILO_COMMAND_STATUS=$?
  
  if [[ $ILO_COMMAND_STATUS == 0 ]]; then
    echo "Set $HOST BootDev:$BOOTDEV=1"
  else
    echo "Problem setting bootsource$BOOTDEV=1 on $HOST!!!"
  fi
}

ilo_boot_set_onetimeboot () {
  local TARGET=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local GENERATION=`ilo_control_get_hw_gen $HOST`
  local ILO_COMMAND_STATUS ILO_COMMAND OUTPUT
  [[ $? == 0 ]] && {
    if [[ "$GENERATION" == "6" ]]; then
      echo "Cannot set onetimeboot for Gen 6 (ILO2) Servers!  Boot $HOST to $TARGET manually. :("
      return 1
    elif [[ "$GENERATION" == "8" ]]; then
      echo "Setting Onetime Boot to $TARGET for $HOST."
      ILO_COMMAND="onetimeboot $TARGET"
      OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_boot_set_onetimeboot`
      ILO_COMMAND_STATUS=$?
    else
      echo "Unknown HW Gen $GENERATION for $HOST!"
      return 1
    fi

    if [[ $ILO_COMMAND_STATUS == 0 ]]; then
      echo "Done setting onetimeboot $TARGET on $HOST"
    else
      echo "Problem setting onetimeboot $TARGET on $HOST"
    fi
  } || {
    echo "Could not get HW Gen for $HOST!"
  }
}


ilo_boot_set_order_these_hosts () {
  local PIDS="" HOST
  local ORDER=$1 HOSTS=$2

  for HOST in $HOSTS now_wait; do
    if ( echo $HOST | grep '[0-9]:[0-9]:[0-9]' ); then
      echo ORDER is $HOST
    elif [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_boot_set_order "$HOST:$ORDER" &
      PIDS="$PIDS:$!"
      echo "Setting boot order for $HOST: $!"
    fi
  done
}


ilo_boot_set_defaults_these_hosts () {
  local HOSTS=$1
  local PIDS="" HOST

  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_boot_set_order "$HOST:$DEFAULT_BOOT_ORDER" &
      PIDS="$PIDS:$!"
      echo "Setting boot defaults for $HOST: $!"
    fi
  done
}

ilo_boot_set_defaults () {
  local HOST=$1
  ilo_boot_set_defaults_these_hosts $HOST
}

ilo_boot_set_onetimeboot_these_hosts () {
  local TARGET=$1 HOSTS=$2
  local HOST PIDS=""

  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_boot_set_onetimeboot $TARGET $HOST &
      PIDS="$PIDS:$!"
      echo "Trying to set onetimeboot for $HOST: $!"
    fi
  done
}


ilo_boot_set_onetimeboot_ipmi () {
  local TARGET=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  ipmitool -I lanplus -H $ILO_IP -U stack -f ilo_pass chassis bootdev $TARGET
}

ilo_boot_set_onetimeboot_ipmi_these_hosts () {
  local PIDS="" HOST TARGET=$1 HOSTS=$2

  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_boot_set_onetimeboot_ipmi $TARGET $HOST &
      PIDS="$PIDS:$!"
      echo "Setting Onetime Boot to PXE for $HOST: $!"
    fi
  done
}


ilo_boot_get_order_these_hosts () {
  local HOSTS=$1
  local PIDS="" HOST PID
  
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ilo_boot_get_order $HOST &
      PIDS="$PIDS:$!"
      echo "Getting boot order for $HOST: $!"
    fi
  done
}
