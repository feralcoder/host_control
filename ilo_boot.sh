#!/bin/bash

DEFAULT_BOOT_ORDER="1:5:2:3:4"

ilo_boot_get_order () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local BOOTS BOOTDEV
  BOOTS=$( echo $(for BOOTDEV in `seq 1 5`; do
    ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "show /system1/bootconfig1/bootsource$BOOTDEV" | grep bootorder | awk -F'=' '{print $2}' | sed  's/.*\([0-9]\).*/\1/g'
  done) | sed 's/ /:/g' )
  echo $HOST:$BOOTS
}


ilo_boot_set_order () {
  local HOST ILO_IP BOOT_ORDER
  read HOST BOOT_ORDER <<< `echo $1 | sed 's/:/ /g' | awk '{print $1 " " $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  
  local -a BOOTS=()
  BOOTS=(${BOOT_ORDER//:/ })

  local BOOTPOSITION DEVICE OUTPUT IN_POST COMPLETED STATUS_TAG
  for BOOTPOSITION in `seq 1 5`; do for DEVICE in `seq 1 5`; do
    COMPLETED=""
    if [[ ${BOOTS[$DEVICE]} == $BOOTPOSITION ]]; then
      while [[ $COMPLETED == "" ]]; do
        OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "set /system1/bootconfig1/bootsource$DEVICE bootorder=$BOOTPOSITION" | tr '\r' '\n')
        COMPLETED=$(echo "$OUTPUT" | grep "status_tag=COMMAND COMPLETED")
        STATUS_TAG=$(echo "$OUTPUT" | grep "status_tag")
        IN_POST=$(echo "$OUTPUT" | grep "unable to set boot orders until system completes POST.")
        if [[ $COMPLETED == "" ]] ; then
          if [[ $IN_POST == "" ]] ; then
            if [[ $STATUS_TAG == "" ]] ; then
              # this is possibly an SSH glitch, not positive unidentified error...
              echo "$HOST Nonpositive error?  Retrying..."
              echo "$OUTPUT"
            else
              echo "$HOST UNKNOWN ERROR, EXITING!!!"
              echo "$OUTPUT"
              return
            fi
          else
            echo "Server $HOST is in POST, retrying in 10 seconds..."
            sleep 10
          fi
        else
          echo "Set $HOST BootDev:$DEVICE=$BOOTPOSITION"
        fi
      done
    fi
  done; done
}


ilo_boot_set_first_boot () {
  local BOOTDEV=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  COMPLETED=""
  while [[ $COMPLETED == "" ]]; do
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "set /system1/bootconfig1/bootsource$BOOTDEV bootorder=1" | tr '\r' '\n')
    COMPLETED=$(echo "$OUTPUT" | grep "status_tag=COMMAND COMPLETED")
    STATUS_TAG=$(echo "$OUTPUT" | grep "status_tag")
    IN_POST=$(echo $OUTPUT | grep "unable to set boot orders until system completes POST.")
    if [[ $COMPLETED == "" ]] ; then
      if [[ $IN_POST == "" ]] ; then
        if [[ $STATUS_TAG == "" ]] ; then
          # this is possibly an SSH glitch, not positive unidentified error...
          echo "$HOST Nonpositive error?  Retrying..."
          echo "$OUTPUT"
        else
          echo "$HOST UNKNOWN ERROR, EXITING!!!"
          echo "$OUTPUT"
          return
        fi
      else
        echo "Server $HOST is in POST, retrying in 10 seconds..."
        sleep 10
      fi
    else
      echo "Set $HOST BootDev:$BOOTDEV=1"
    fi
  done
}




ilo_boot_set_order_these_hosts () {
  local PIDS="" HOST
  local ORDER=$1

  for HOST in $@ now_wait; do
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
      ilo_boot_set_order "$HOST:$DEFAULT_BOOT_ORDER" &
      PIDS="$PIDS:$!"
      echo "Setting boot defaults for $HOST: $!"
    fi
  done
}

ilo_boot_set_defaults_all_hosts () {
  ilo_boot_set_defaults_these_hosts $ILO2_HOSTS $ILO4_HOSTS
}

ilo_boot_set_defaults_all_ilo2_hosts () {
  ilo_boot_set_defaults_these_hosts $ILO2_HOSTS
}

ilo_boot_set_onetimeboot () {
  local TARGET=$1 HOST=$2
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local GENERATION=`ilo_control_get_hw_gen $HOST`
  [[ $? == 0 ]] && {
    if [[ "$GENERATION" == "6" ]]; then
      echo "Cannot set onetimeboot for Gen 6 (ILO2) Servers!  Boot $HOST to $TARGET manually. :("
      return 1
    elif [[ "$GENERATION" == "8" ]]; then
      ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "onetimeboot $TARGET"
      echo "Setting Onetime Boot to $TARGET for $HOST."
    else
      echo "Unknown HW Gen $GENERATION for $HOST!"
      return 1
    fi
  } || {
    echo "Could not get HW Gen for $HOST!"
  }

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


ilo_boot_set_onetimeboot_ipmi_all_hosts () {
  local TARGET=$1
  ilo_boot_set_onetimeboot_ipmi_these_hosts $TARGET "$ILO2_HOSTS $ILO4_HOSTS"
}

ilo_boot_set_onetimeboot_ipmi_all_ilo4_hosts () {
  local TARGET=$1
  ilo_boot_set_onetimeboot_ipmi_these_hosts $TARGET "$ILO4_HOSTS"
}

ilo_boot_set_onetimeboot_ipmi_all_ilo2_hosts () {
  local TARGET=$1
  ilo_boot_set_onetimeboot_ipmi_these_hosts $TARGET "$ILO2_HOSTS"
}

ilo_boot_get_order_these_hosts () {
  local PIDS="" HOST PID
  for HOST in $@ now_wait; do
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


ilo_boot_get_order_all_hosts () {
  local PID_ILO2 PID_ILO4
  ilo_boot_get_order_these_hosts $ILO2_HOSTS &
  PID_ILO2="$!"
  echo "Getting boot order for ILO2 Servers: $PID_ILO2"
  ilo_boot_get_order_these_hosts $ILO4_HOSTS &
  PID_ILO4="$!"
  echo "Getting boot order for ILO4 Servers: $PID_ILO4"
  wait $PID_ILO2
  wait $PID_ILO4
}
