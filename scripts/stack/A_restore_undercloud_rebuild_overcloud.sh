#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

BUILD_OPTIONS=$1
[[ $BUILD_OPTIONS == "" ]] && {
  BUILD_OPTIONS="DEFOPTS=true"
}

BUILT_UNDERCLOUD_LINK=$2
[[ $BUILT_UNDERCLOUD_LINK == "" ]] && {
  BUILT_UNDERCLOUD_LINK=dumbledoreB_02_Ussuri_Undercloud_HA_NoVlans
}


RESTORE_UNDERCLOUD=". $THIS_SOURCE/02a_undercloud_restore_undercloud.sh $BUILT_UNDERCLOUD_LINK"
WIPE_OVERCLOUD=". $THIS_SOURCE/03_overcloud_reset.sh"

declare -A OUTPUT TASKS_BY_PID FD_BY_TASK
declare PID PIDS="" HOST
FD=5
for TASK in "$RESTORE_UNDERCLOUD" "$WIPE_OVERCLOUD" now_wait; do
  if [[ $TASK == "now_wait" ]]; then
    PIDS=`echo $PIDS | sed 's/^://g'`
    for PID in `echo $PIDS | sed 's/:/ /g'`; do
      wait ${PID}
      echo "Return code for PID $PID: $?"
    done
    for PID in `echo $PIDS | sed 's/:/ /g'`; do
      echo "_________________________________"
      TASK=${TASKS_BY_PID["_$PID"]}
      echo "PID $PID is $TASK"
      echo "Output for $TASK:"
      FD=${FD_BY_TASK[$TASK]}
      cat /tmp/$$_$FD
      echo "_________________________________"
      rm /tmp/$$_$FD
    done
    continue
  else
    ((FD=$FD+1))
    FD_BY_TASK[$TASK]=$FD
    echo $TASK | bash > /tmp/$$_$FD &
    PID=$!
    PIDS="$PIDS:$!"
    TASKS_BY_PID["_$PID"]=$TASK
  fi
  echo "Started $TASK"
  echo "$PIDS"
done

. $THIS_SOURCE/04_undercloud_build_overcloud.sh $BUILD_OPTIONS
