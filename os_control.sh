#!/bin/bash

. ilo_common.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh

. ssh_control.sh

SYSTEM_ILO=2
DEBUG=true

os_control_graceful_stop () {
  local HOST=$1 IP=$2 ILO_IP=$3

  ssh_control_run_as_user root poweroff $HOST $IP
  OUTPUT=`ssh_control_wait_for_host_down $HOST $ILO_IP`
  [[ $? == 0 ]] || ilo_power_off $HOST $ILO_IP
  OUTPUT=`ssh_control_wait_for_host_down $HOST $ILO_IP`
  [[ $? == 0 ]] || return 1
}

os_control_graceful_stop_these_hosts () {
  local PIDS="" HOST IP ILO_IP

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
      local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      os_control_graceful_stop $HOST $IP $ILO_IP
      PIDS="$PIDS:$!"
      echo "Stopping $HOST..."
    fi
  done
}


# STATE="BOOTED|IN_BETWEEN|OFF"
os_control_get_system_state () {
  local HOST=$1
  local IP=`getent hosts $HOST | awk '{print $1}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  local LOGIN_STATE STATE RETVAL
  local PWR_STATE=$(ilo_power_get_state $HOST $ILO_IP | awk '{print $3}')

  if [[ $PWR_STATE == On ]]; then
    HOSTNAME=`ssh_control_run_as_user root hostname $HOST $IP`
    RETVAL=$?
    if [[ $RETVAL == 0 ]]; then
      STATE="BOOTED"
    else
      STATE="IN_BETWEEN"
      echo $STATE
      return 1
    fi
  else
    STATE="OFF"
    echo $STATE
    return 2
  fi
  echo $STATE
}

# RETURN "$BOOTDEV:$INSTALLATION=admin|default"
os_control_boot_info () {
  local HOST=$1
  local IP=`getent hosts $HOST | awk '{print $1}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  local INSTALLATION HOSTNAME BOOTDEV
  local STATE=$(os_control_get_system_state $HOST $IP)
  if [[ $STATE == "BOOTED" ]]; then
    HOSTNAME=$(ssh_control_run_as_user root hostname $HOST $IP)
    if [[ $(echo $HOSTNAME | awk -F'.' '{print $1}' | awk -F'-' '{print $2}') == "admin" ]]; then
      INSTALLATION="admin"
    else
      INSTALLATION="default"
    fi
    BOOTDEV=$(ssh_control_run_as_user root "mount" $HOST $IP | grep ' /boot ' | awk '{print $1}')
  elif [[ $STATE == "IN_BETWEEN" ]]; then
    echo "$HOST is not BOOTED!"
    return 1
  elif [[ $STATE == "OFF" ]]; then
    echo "$HOST is OFF!"
    return 2
  else
    echo "$HOST is in UNKNON STATE!"
    return 128
  fi

  echo "$BOOTDEV:$INSTALLATION"
}

os_control_boot_to_target_installation () {
  # $TARGET==[admin|default]
  local HOST=$1 TARGET=$2
  local IP=`getent hosts $HOST | awk '{print $1}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
  
  local OUTPUT
  local OS_BOOT_INFO=`os_control_boot_info $HOST $IP`
  local RETVAL=$?

  # IF IN_BETWEEN OFF and BOOTED, GET TO A DETERMINATE STATE
  if [[ $RETVAL == 1 ]]; then
    # host may be booting...
    OUTPUT=`ssh_control_wait_for_host_up $HOST $IP`
    # Wait a long time for an OS before kicking over
    if [[ $RETVAL != 0 ]]; then
      OUTPUT=`ssh_control_wait_for_host_up $HOST $IP`
      if [[ $? != 0 ]]; then
        OUTPUT=$(ilo_power_off $HOST $ILO_IP)
        OUTPUT=`ssh_control_wait_for_host_down $HOST $ILO_IP`
        [[ $? == 0 ]] || { echo ERROR shutting down $HOST!; return 1; }
      fi
    fi
    OS_BOOT_INFO=`os_control_boot_info $HOST $IP`
    RETVAL=$?
  fi

  # HOST SHOULD BE OFF OR BOOTED AT THIS POINT
  if [[ $RETVAL == 0 ]]; then
    # host is booted
    if [[ $(echo $OS_BOOT_INFO | awk -F':' '{print $2}') == "$TARGET" ]]; then
      # WE'RE DONE!
      echo "$HOST is booted to $TARGET"
      return
    else
      # POWER OFF HOST
      OUTPUT=$(ssh_control_run_as_user root poweroff $HOST $IP)
      OUTPUT=`ssh_control_wait_for_host_down $HOST $ILO_IP`
      if [[ $? != 0 ]]; then
        OUTPUT=$(ilo_power_off $HOST $ILO_IP)
        OUTPUT=`ssh_control_wait_for_host_down $HOST $ILO_IP`
        [[ $? == 0 ]] || { echo ERROR shutting down $HOST!; return 1; }
      fi
    fi
  elif [[ $RETVAL != 2 ]]; then
    # HOST SHOULD BE OFF BY NOW
    echo "$HOST is in UNKNOWN STATE"
    return 1
  fi

  OS_BOOT_INFO=`os_control_boot_info $HOST $IP`
  RETVAL=$?

  # HOST SHOULD BE OFF AT THIS POINT
  if [[ $RETVAL == 2 ]]; then
    # HERE WE GO
    if [[ $TARGET == "admin" ]]; then
      if [[ $SYSTEM_ILO == "2" ]]; then
        OUTPUT=$(ilo_boot_target_once_ilo2 $DEV_USB $HOST)
      elif [[ $SYSTEM_ILO == "4" ]]; then
        OUTPUT=$(ilo_boot_target_once_ilo4 $DEV_USB $HOST)
      fi
    else
      OUTPUT=$(ilo_power_on $HOST $ILO_IP)
    fi
    OUTPUT=`ssh_control_wait_for_host_up $HOST $IP`
    if [[ $? != 0 ]]; then
      OUTPUT=`ssh_control_wait_for_host_up $HOST $IP`
      [[ $? == 0 ]] || { echo "ERROR BOOTING $HOST!"; return 1; }
    fi
  else
    echo "$HOST should be OFF and is NOT!"
    return 1
  fi

  OS_BOOT_INFO=`os_control_boot_info $HOST $IP`
  RETVAL=$?

  # HOST SHOULD BE BOOTED TO $TARGET AT THIS POINT
  if [[ $RETVAL == 0 ]]; then
    if [[ $(echo $OS_BOOT_INFO | awk -F':' '{print $2}') == "$TARGET" ]]; then
      # WE'RE DONE!
      echo "$HOST is booted to $TARGET"
      return
    else
      echo "$HOST is BOOTED but OS is NOT $TARGET!"
      return 1
    fi
  else
    echo "$HOST should be BOOTED and is NOT!"
    return 1
  fi
}
