#!/bin/bash

. ilo_common.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh

. ssh_control.sh
. os_control.sh
. undercloud_control.sh


UNDERCLOUD_HOST=dmb
UNDERCLOUD_IP=`getent hosts $UNDERCLOUD_HOST | awk '{print $1}'`


get_instance_ips_all () {
  local INSTANCE_OUTPUT="`run_as_user root "su - stack -c '. stackrc && nova list'" $UNDERCLOUD_HOST $UNDERCLOUD_IP`"
  [[ $? == 0 ]] || { echo "Error fetching nova list, check your stack!  Exiting!"; return 1; }

  INSTANCE_OUTPUT="$(echo "$INSTANCE_OUTPUT" | grep -E '[^ -]{3,}-[^ -]{3,}')"
  echo "$INSTANCE_OUTPUT" | awk '{print $2 ":" $12}' | sed 's/ctlplane=//g'
}

get_instance_ip () {
  local INSTANCE=$1 IP

  IP=$(get_instance_ips | grep $INSTANCE | awk -F':' '{print $2}')
}

get_node_ip_these_hosts () {
  local HOST LONG_HOST NODE_OUTPUT INSTANCE_ID INSTANCE_IPS IP
  local HOST_LIST=""

  NODE_OUTPUT="`run_as_user root "su - stack -c '. stackrc && openstack baremetal node list'" $UNDERCLOUD_HOST $UNDERCLOUD_IP`"
  [[ $? == 0 ]] || { echo "Error fetching node list, check your stack!  Exiting!"; return 1; }

  HOST_LIST="$(for HOST in $@; do
    LONG_HOST=`getent hosts $HOST | awk '{print $2}' | awk -F'\.' '{print $1}'`
    INSTANCE_ID=$(echo "$NODE_OUTPUT" | grep $LONG_HOST | awk '{print $6}')
    echo "$HOST:$INSTANCE_ID"
  done)"

  INSTANCE_IPS="$(get_instance_ips_all)"

  for HOST in $@; do
    INSTANCE_ID=$(echo "$HOST_LIST" | grep "$HOST:" | awk -F':' '{print $2}')
    if [[ $(echo $INSTANCE_ID | grep  -E '[^ -]{3,}-[^ -]{3,}') == "" ]] ; then
      # This host has no instance
      IP=UNKNOWN
    else
      IP=$(echo "$INSTANCE_IPS" | grep $INSTANCE_ID | awk -F':' '{print $2}')
    fi
    echo "$HOST:$IP"
  done
}

get_node_ip () {
  local HOST=$1
  get_node_ip_these_hosts $HOST
}

graceful_stop_node () {
  local HOST=$1 NODE_IP=$2 IP=$3 ILO_IP=$4

 run_as_user root "su - stack -c '. stackrc && ssh heat-admin@$NODE_IP sudo poweroff'" $UNDERCLOUD_HOST $UNDERCLOUD_IP
  OUTPUT=`wait_for_host_down $HOST $ILO_IP`
  [[ $? == 0 ]] || power_off $HOST $ILO_IP
  OUTPUT=`wait_for_host_down $HOST $ILO_IP`
  [[ $? == 0 ]] || return 1
}

graceful_stop_node_these_hosts () {
  local PIDS="" HOST IP ILO_IP NODE_IP

  local NODE_IPS="$(get_node_ip_these_hosts $@)"

  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      IP=`getent hosts $HOST | awk '{print $1}'`
      ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      NODE_IP=$(echo "$NODE_IPS" | grep $HOST | awk -F':' '{print $2}')

      graceful_stop_node $HOST $NODE_IP $IP $ILO_IP &

      PIDS="$PIDS:$!"
      echo "Stopping $HOST..."
    fi
  done
}

shutdown_stack () {
  local CONTROL_WAIT=300
  local IP ILO_IP

  echo "Bringing down Compute Nodes: $COMPUTE_HOSTS"
  graceful_stop_node_these_hosts $COMPUTE_HOSTS
  echo "Bringing down Control Nodes: $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS"

  local HOST
  for HOST in $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS; do
    echo "Stopping: $HOST"
    IP=`getent hosts $HOST | awk '{print $1}'`
    ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
    graceful_stop_node_these_hosts $HOST
    [[ $? == 0 ]] || { echo "Failed to stop Control Node: $HOST, EXITING!"; return 1; }

    echo "Control Node $HOST Stopped.  Waiting $CONTROL_WAIT seconds to proceed."
    sleep $CONTROL_WAIT
  done
}

startup_stack () {
  # THIS NEEDS WORK - NO STARTUP VALIDATION - root logins don't work!
  echo "Starting Stack..."
  local CONTROL_WAIT=300
  local HOST IP ILO_IP

  echo "Bringing up Control Nodes: $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"
  for HOST in $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS; do
    IP=`getent hosts $HOST | awk '{print $1}'`
    ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
    echo "Starting: $HOST"
    # boot_to_target_installation $HOST default
    # Above command validates boot via ssh login - which won't work after stack nodes are built!
    power_on $HOST $ILO_IP
    # Add wait_for_host_up - via stack user heat-admin...
    echo "Control Node $HOST Starting.  Cannot verify, waiting $CONTROL_WAIT seconds to proceed."
    sleep $CONTROL_WAIT
  done

  echo "Bringing up Compute Nodes: $COMPUTE_HOSTS"
  power_on_these_hosts $COMPUTE_HOSTS
  echo "Cannot verify, exiting now.  Wait a while..."
}


