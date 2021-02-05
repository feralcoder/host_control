#!/bin/bash


get_boot_defaults () {
  local HOST=$1 IP=$2

  local BOOTS BOOTDEV
  BOOTS=$( echo $(for BOOTDEV in `seq 1 5`; do
    ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "show /system1/bootconfig1/bootsource$BOOTDEV" | grep bootorder | awk -F'=' '{print $2}' | sed  's/.*\([0-9]\).*/\1/g'
  done) | sed 's/ /:/g' )
  echo $HOST:$IP:$BOOTS
}


set_boot_defaults () {
  local HOST IP BOOT_ORDER
  read HOST IP BOOT_ORDER <<< `echo $1 | sed 's/:/ /g' | awk '{print $1 " " $2 " " $1 ":" $3 ":" $4 ":" $5 ":" $6 ":" $7}'`
  
  local -a BOOTS=()
  BOOTS=(${BOOT_ORDER//:/ })

  local BOOTPOSITION DEVICE OUTPUT IN_POST COMPLETED STATUS_TAG
  for BOOTPOSITION in `seq 1 5`; do for DEVICE in `seq 1 5`; do
    COMPLETED=""
    if [[ ${BOOTS[$DEVICE]} == $BOOTPOSITION ]]; then
      while [[ $COMPLETED == "" ]]; do
        OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "set /system1/bootconfig1/bootsource$DEVICE bootorder=$BOOTPOSITION" | tr '\r' '\n')
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


set_first_boot () {
  local BOOTDEV=$1 HOST=$2 IP=$3
  COMPLETED=""
  while [[ $COMPLETED == "" ]]; do
    OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $IP -l stack "set /system1/bootconfig1/bootsource$BOOTDEV bootorder=1" | tr '\r' '\n')
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




set_boot_defaults_for_these_hosts () {
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
      set_boot_defaults "$HOST:$IP:1:5:2:3:4" &
      PIDS="$PIDS:$!"
      echo "Setting boot defaults for $HOST: $!"
    fi
  done
}

set_boot_defaults_for_all_hosts () {
  set_boot_defaults_for_these_hosts $ILO2_HOSTS $ILO4_HOSTS
}

set_boot_defaults_for_all_ilo2_hosts () {
  set_boot_defaults_for_these_hosts $ILO2_HOSTS
}

set_boot_defaults_for_dumbledore () {
  set_boot_defaults_for_these_hosts dmb
}



set_onetimeboot_ipmi () {
  local TARGET=$1 HOST=$2 IP=$3

  ipmitool -I lanplus -H $IP -U stack -f ilo_pass chassis bootdev $TARGET
}

set_onetimeboot_ipmi_for_these_hosts () {
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
      local IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      set_onetimeboot_ipmi $TARGET $HOST $IP &
      PIDS="$PIDS:$!"
      echo "Setting Onetime Boot to PXE for $HOST: $!"
    fi
  done
}


set_onetimeboot_ipmi_for_all_hosts () {
  local TARGET=$1
  set_onetimeboot_ipmi_for_these_hosts $TARGET "$ILO2_HOSTS $ILO4_HOSTS"
}

set_onetimeboot_ipmi_for_all_ilo4_hosts () {
  local TARGET=$1
  set_onetimeboot_ipmi_for_these_hosts $TARGET "$ILO4_HOSTS"
}

set_onetimeboot_ipmi_for_all_ilo2_hosts () {
  local TARGET=$1
  set_onetimeboot_ipmi_for_these_hosts $TARGET "$ILO2_HOSTS"
}

