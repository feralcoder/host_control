#!/bin/bash

boot_target_once_ilo2 () {
  local TARGET=$1 HOST=$2
  local IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  STATE=$(get_power_state $HOST $IP | awk '{print $3}')
  [[ $STATE == "Off" ]] || { echo "Server $HOST is ON, Exiting!"; return 1; }

  local ORIG_BOOTS=`get_boot_defaults $HOST $IP`
  set_first_boot $TARGET $HOST $IP
  power_on $HOST $IP
  sleep 10
  set_boot_defaults $ORIG_BOOTS
}


boot_target_once_ilo4 () {
  local TARGET=$1 HOST=$2
  local IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  STATE=$(get_power_state $HOST $IP | awk '{print $3}')
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
      
  OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "onetimeboot $target")
  power_on $HOST $IP
}

boot_target_once_ilo2_these_hosts () {
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
      boot_target_once_ilo2 $TARGET $HOST &
      PIDS="$PIDS:$!"
      echo "Started Targeted DEV=$TARGET boot for $HOST: $!"
    fi
  done
}

boot_target_once_ilo4_these_hosts () {
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
      boot_target_once_ilo4 $TARGET $HOST &
      PIDS="$PIDS:$!"
      echo "Started Targeted DEV=$TARGET boot for $HOST: $!"
    fi
  done
}


boot_target_once_all_hosts () {
  local TARGET=$1

  local PID_ILO2 PID_ILO4
  boot_target_once_ilo2_these_hosts $TARGET "$ILO2_HOSTS" &
  PID_ILO2="$!"
  echo "Started Targeted DEV=$TARGET Boot for ILO2 Servers: $PID_ILO2"
  boot_target_once_ilo4_these_hosts $TARGET "$ILO4_HOSTS" &
  PID_ILO4="$!"
  echo "Started Targeted DEV=$TARGET Boot for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}





get_boot_defaults_these_hosts () {
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
      local IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      get_boot_defaults $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Getting boot defaults for $HOST: $!"
    fi
  done
}


get_boot_defaults_all_hosts () {
  local PID_ILO2 PID_ILO4
  get_boot_defaults_these_hosts $ILO2_HOSTS &
  PID_ILO2="$!"
  echo "Getting boot defaults for ILO2 Servers: $PID_ILO2"
  get_boot_defaults_these_hosts $ILO4_HOSTS &
  PID_ILO4="$!"
  echo "Getting boot defaults for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}


