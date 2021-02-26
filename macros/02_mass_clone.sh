#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

HOSTS="kgn neo bmn lmn mtn dmb"
SRC_PREFIX=b
DEST_PREFIX=a

admin_control_clone_and_fix_labels () {
  local SRC_PREFIX=$1 DEST_PREFIX=$2 HOST=$3

  local SHORT_NAME SRC_DISK DEST_DISK SRC_DEV DEST_DEV
  SHORT_NAME=`group_logic_get_short_name $HOST`
  SRC_DISK=${SRC_PREFIX}$SHORT_NAME
  DEST_DISK=${DEST_PREFIX}$SHORT_NAME
  SRC_DEV=`ssh_control_run_as_user root "blkid | grep $SRC_DISK" $HOST | grep ${SRC_DISK}_boot | awk '{print $1}' | tr '\n' ' ' | sed 's/[0-9]:.*//g'`
  DEST_DEV=`ssh_control_run_as_user root "blkid | grep $DEST_DISK" $HOST | grep ${DEST_DISK}_boot | awk '{print $1}' | tr '\n' ' ' | sed 's/[0-9]:.*//g'`
  ( admin_control_clone $SRC_DEV $DEST_DEV $HOST && 
    admin_control_fix_labels $DEST_DEV $DEST_PREFIX $HOST ) > \
    "/tmp/mass_clone_${HOST}_${SRC_DISK}_${DEST_DISK}_$$.log"

  PIDS="$PIDS:$!"
  echo "Cloning $SRC_DEV to $DEST_DEV on $HOST."
}



admin_control_clone_and_fix_labels_these_hosts () {
  local SRC_PREFIX=$1 DEST_PREFIX=$2 HOSTS=$3

  local RETURN_CODE HOST PID SHORT_NAME SRC_DISK DEST_DISK SRC_DEV DEST_DEV PIDS
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Mass clone, SRC_PREFIX:$SRC_PREFIX DEST_PREFIX:$DEST_PREFIX"
        fi
      done
    else
      admin_control_clone_and_fix_labels $SRC_PREFIX $DEST_PREFIX $HOST > "/tmp/mass_clone_${HOST}_${SRC_PREFIX}_${DEST_PREFIX}_$$.log" &

      PIDS="$PIDS:$!"
      echo "Cloning $SRC_PREFIX to $DEST_PREFIX on $HOST."
    fi
  done
}


admin_control_clone_and_fix_labels_these_hosts $SRC_PREFIX $DEST_PREFIX "$HOSTS"
