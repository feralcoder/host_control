#!/bin/bash

ilo_boot_target_once_ilo2 () {
  local TARGET=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  STATE=$(ilo_power_get_state $HOST $ILO_IP | awk '{print $3}')
  [[ $STATE == "Off" ]] || { echo "Server $HOST is ON, Exiting!"; return 1; }

  local ORIG_BOOTS=`ilo_boot_get_order $HOST $ILO_IP`
  ilo_boot_set_first_boot $TARGET $HOST $ILO_IP
  ilo_power_on $HOST $ILO_IP
  sleep 10
  ilo_boot_set_order $ORIG_BOOTS
}


ilo_boot_target_once_ilo4 () {
  local TARGET=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  STATE=$(ilo_power_get_state $HOST $ILO_IP | awk '{print $3}')
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
      
  OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "onetimeboot $target")
  ilo_power_on $HOST $ILO_IP
}

ilo_boot_target_once_ilo2_these_hosts () {
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
      ilo_boot_target_once_ilo2 $TARGET $HOST &
      PIDS="$PIDS:$!"
      echo "Started Targeted DEV=$TARGET boot for $HOST: $!"
    fi
  done
}

ilo_boot_target_once_ilo4_these_hosts () {
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
      ilo_boot_target_once_ilo4 $TARGET $HOST &
      PIDS="$PIDS:$!"
      echo "Started Targeted DEV=$TARGET boot for $HOST: $!"
    fi
  done
}


ilo_boot_target_once_all_hosts () {
  local TARGET=$1

  local PID_ILO2 PID_ILO4
  ilo_boot_target_once_ilo2_these_hosts $TARGET "$ILO2_HOSTS" &
  PID_ILO2="$!"
  echo "Started Targeted DEV=$TARGET Boot for ILO2 Servers: $PID_ILO2"
  ilo_boot_target_once_ilo4_these_hosts $TARGET "$ILO4_HOSTS" &
  PID_ILO4="$!"
  echo "Started Targeted DEV=$TARGET Boot for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}





