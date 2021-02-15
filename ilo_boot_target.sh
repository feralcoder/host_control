#!/bin/bash

ilo_boot_target_once_ilo2 () {
  local TARGET=$1 HOST=$2

  STATE=$(ilo_power_get_state $HOST | awk '{print $3}')
  [[ $STATE == "Off" ]] || { echo "Server $HOST is ON, Exiting!"; return 1; }

  local ORIG_BOOTS=`ilo_boot_get_order $HOST`
  [[ $DEBUG == "" ]] || echo "IN boot_target_once_ilo2 $TARGET $HOST.  Orig boot order: $ORIG_BOOTS" 1>&2
  ilo_boot_set_first_boot $TARGET $HOST
  [[ $DEBUG == "" ]] || {
    echo "DEBUG: Just set first boot to $TARGET, getting order now..." 1>&2
    local CURRENT_BOOTS=`ilo_boot_get_order $HOST`
    echo "DEBUG: CURRENT_BOOTS: $CURRENT_BOOTS" 1>&2
  }
  ilo_power_on $HOST
  sleep 10
  ilo_boot_set_order $ORIG_BOOTS
  [[ $DEBUG == "" ]] || {
    echo "DEBUG: Just reset order to $ORIG_BOOTS, getting order now..." 1>&2
    local CURRENT_BOOTS=`ilo_boot_get_order $HOST`
    echo "DEBUG: CURRENT_BOOTS: $CURRENT_BOOTS" 1>&2
  }
}


ilo_boot_target_once_ilo4 () {
  local TARGET=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  STATE=$(ilo_power_get_state $HOST | awk '{print $3}')
  [[ $STATE == "Off" ]] || { echo "Server $HOST is ON, Exiting!"; return 1; }

  local target
  case $TARGET in
    $DEV_PXE)
      target="pxe"
      ;;
    $DEV_USB)
      target="usb"
      ;;
  esac
      
  local ILO_COMMAND="onetimeboot $target"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_boot_target_once_ilo4`
  [[ $? == 0 ]] || echo "Problem setting onetimeboot to $target on $HOST" 1>&2

  ilo_power_on $HOST
  [[ $? == 0 ]] && echo "$HOST is onetimebooting to $target" 1>&2 || echo "Problem powering on $HOST" 1>&2
}



ilo_boot_target_once_these_hosts () {
  local TARGET=$1 HOSTS=$2

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
      GENERATION=`ilo_control_get_hw_gen $HOST`
      [[ $? == 0 ]] && {
        if [[ "$GENERATION" == "6" ]]; then
          ilo_boot_target_once_ilo2 $TARGET $HOST &
          PIDS="$PIDS:$!"
        elif [[ "$GENERATION" == "8" ]]; then
          ilo_boot_target_once_ilo4 $TARGET $HOST &
          PIDS="$PIDS:$!"
        else
          echo "Unknown HW Gen $GENERATION for $HOST!"
          continue
        fi
        echo "Started Targeted DEV=$TARGET boot for $HOST: $!"
      } || {
        echo "Could not get HW Gen for $HOST!"
      }
    fi
  done
}

ilo_boot_target_once () {
  local TARGET=$1 HOST=$2
  ilo_boot_target_once_these_hosts $TARGET $HOST
}
