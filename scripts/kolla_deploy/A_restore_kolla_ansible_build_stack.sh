#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

BUILD_OPTIONS=$1
[[ $BUILD_OPTIONS == "" ]] && {
  BUILD_OPTIONS="DEFOPTS=true"
}

BUILT_KOLLA_LINK=$2
[[ $BUILT_KOLLA_LINK == "" ]] && {
  BUILT_KOLLA_LINK=dumbledoreB_02_Kolla_Ansible
}


RESTORE_KOLLA=". $THIS_SOURCE/01d_restore_kolla_ansible.sh $BUILT_KOLLA_LINK"
WIPE_STACK=". $THIS_SOURCE/03a_wipe_stack.sh"

declare -A OUTPUT TASKS_BY_PID FD_BY_TASK
declare PID PIDS="" HOST
FD=5
for TASK in "$RESTORE_KOLLA" "$WIPE_STACK" now_wait; do
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

. $THIS_SOURCE/03b_build_stack.sh $BUILD_OPTIONS
