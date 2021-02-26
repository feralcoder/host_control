#!/bin/bash

UNDERCLOUD_HOST=dmb
UNDERCLOUD_IP=`getent ahosts $UNDERCLOUD_HOST | awk '{print $1}' | tail -n 1`


stack_control_build_the_whole_fucking_thing () {
  local HOST=$1

  backup_control_restore dmb admb /backups/undercloud_dumps/dumbledore_01_CentOS_8 default
  ssh_control_run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_undercloud.sh" dmb
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_undercloud.sh" dmb)
  # [[ $OUTPUT == "UNDERCLOUD OK" ]] || { echo "Undercloud installation incomplete, check it out!"; return 1; }
  backup_control_backup dmb admb /backups/undercloud_dumps default new-dumbledore_02_Ussuri_Undercloud
  ssh_control_run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_overcloud.sh" dmb
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_overcloud.sh" dmb)
  # [[ $OUTPUT == "OVERCLOUD OK" ]] || { echo "Overcloud installation incomplete, check it out!"; return 1; }
  backup_control_backup dmb admb /backups/undercloud_dumps default new-dumbledore_03_Ussuri_Overcloud
}

stack_control_get_instance_ips_all () {
  local INSTANCE_OUTPUT="`ssh_control_run_as_user root "su - stack -c '. stackrc && nova list'" $UNDERCLOUD_HOST $UNDERCLOUD_IP`"
  [[ $? == 0 ]] || { echo "Error fetching nova list, check your stack!  Exiting!"; return 1; }

  INSTANCE_OUTPUT="$(echo "$INSTANCE_OUTPUT" | grep -E '[^ -]{3,}-[^ -]{3,}')"
  echo "$INSTANCE_OUTPUT" | awk '{print $2 ":" $12}' | sed 's/ctlplane=//g'
}

stack_control_get_instance_ip () {
  local INSTANCE=$1 INSTANCE_IP

  INSTANCE_IP=$(stack_control_get_instance_ips | grep $INSTANCE | awk -F':' '{print $2}')
}

stack_control_get_node_ip_these_hosts () {
  local HOSTS=$1
  local HOST LONG_HOST NODE_OUTPUT INSTANCE_ID INSTANCE_IPS INSTANCE_IP
  local HOST_LIST=""

  NODE_OUTPUT="`ssh_control_run_as_user root "su - stack -c '. stackrc && openstack baremetal node list'" $UNDERCLOUD_HOST $UNDERCLOUD_IP`"
  [[ $? == 0 ]] || { echo "Error fetching node list, check your stack!  Exiting!"; return 1; }

  HOST_LIST="$(for HOST in $HOSTS; do
    LONG_HOST=`getent ahosts $HOST | awk '{print $2}' | awk -F'\.' '{print $1}' | tail -n 1`
    INSTANCE_ID=$(echo "$NODE_OUTPUT" | grep $LONG_HOST | awk '{print $6}')
    echo "$HOST:$INSTANCE_ID"
  done)"

  INSTANCE_IPS="$(stack_control_get_instance_ips_all)"

  for HOST in $HOSTS; do
    INSTANCE_ID=$(echo "$HOST_LIST" | grep "$HOST:" | awk -F':' '{print $2}')
    if [[ $(echo $INSTANCE_ID | grep  -E '[^ -]{3,}-[^ -]{3,}') == "" ]] ; then
      # This host has no instance
      INSTANCE_IP=UNKNOWN
    else
      INSTANCE_IP=$(echo "$INSTANCE_IPS" | grep $INSTANCE_ID | awk -F':' '{print $2}')
    fi
    echo "$HOST:$INSTANCE_IP"
  done
}

stack_control_get_node_ip () {
  local HOST=$1
  stack_control_get_node_ip_these_hosts $HOST
}

stack_control_graceful_stop_node () {
  local HOST=$1 INSTANCE_IP=$2

  ssh_control_run_as_user root "su - stack -c '. stackrc && ssh heat-admin@$INSTANCE_IP sudo poweroff'" $UNDERCLOUD_HOST $UNDERCLOUD_IP
  OUTPUT=`ssh_control_wait_for_host_down $HOST`
  [[ $? == 0 ]] || power_off $HOST
  OUTPUT=`ssh_control_wait_for_host_down $HOST`
  [[ $? == 0 ]] || return 1
}

stack_control_graceful_stop_node_these_hosts () {
  local HOSTS=$1
  local PIDS="" HOST INSTANCE_IP

  local INSTANCE_IPS="$(stack_control_get_node_ip_these_hosts '$HOSTS')"

  local RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Graceful node stop, no more info available"
        fi
      done
    else
      INSTANCE_IP=$(echo "$INSTANCE_IPS" | grep $HOST | awk -F':' '{print $2}')

      stack_control_graceful_stop_node $HOST $INSTANCE_IP &

      PIDS="$PIDS:$!"
      echo "Stopping $HOST..."
    fi
  done
}

stack_control_shutdown_stack () {
  local CONTROL_WAIT=300

  echo "Bringing down Compute Nodes: $COMPUTE_HOSTS"
  stack_control_graceful_stop_node_these_hosts "$COMPUTE_HOSTS"
  echo "Bringing down Control Nodes: $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS"

  local HOST
  for HOST in $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS; do
    echo "Stopping: $HOST"
    stack_control_graceful_stop_node_these_hosts $HOST
    [[ $? == 0 ]] || { echo "Failed to stop Control Node: $HOST, EXITING!"; return 1; }

    echo "Control Node $HOST Stopped.  Waiting $CONTROL_WAIT seconds to proceed."
    sleep $CONTROL_WAIT
  done
}

stack_control_startup_stack () {
  # THIS NEEDS WORK - NO STARTUP VALIDATION - root logins don't work!
  echo "Starting Stack..."
  local CONTROL_WAIT=300
  local HOST

  echo "Bringing up Control Nodes: $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"
  for HOST in $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS; do
    echo "Starting: $HOST"
    # boot_to_target_installation $HOST default
    # Above command validates boot via ssh login - which won't work after stack nodes are built!
    ilo_power_on $HOST
    # Add wait_for_host_up - via stack user heat-admin...
    echo "Control Node $HOST Starting.  Cannot verify, waiting $CONTROL_WAIT seconds to proceed."
    sleep $CONTROL_WAIT
  done

  echo "Bringing up Compute Nodes: $COMPUTE_HOSTS"
  ilo_power_on_these_hosts "$COMPUTE_HOSTS"
  echo "Cannot verify, exiting now.  Wait a while..."
}
