#!/bin/bash -x


kolla_control_make_ceph_bluestore_OSD () {
  local HOST=$1 BLOCK_DEVICE=$2 SUFFIX=$3 DB_DEVICE=$4 WAL_DEVICE=$5
  # BLOCK_DEVICE=/dev/sdx       (REQUIRED)
  # SUFFIX=ANYTHING             (OPTIONAL, but required if 2+ OSD's ON SYSTEM with WAL or DB devices)
  # DB_DEVICE=/dev/sdx          (OPTIONAL, if empty DB will write to block device)
  # WAL_DEVICE=/dev/sdx         (OPTIONAL, if empty WAL will write to DB device if it exists, or block device)

  local LABEL=KOLLA_CEPH_OSD_BOOTSTRAP_BS
  [[ $SUFFIX == "" ]] || LABEL=${LABEL}_$SUFFIX
 
  if [[ $DB_DEVICE == "" ]] && [[ $WAL_DEVICE == "" ]]; then
    ssh_control_run_as_user root "parted $BLOCK_DEVICE -s -- mklabel gpt mkpart $LABEL 1 -1" $HOST
  else
    ssh_control_run_as_user root "parted $BLOCK_DEVICE -s -- mklabel gpt mkpart ${LABEL}_B 1 -1" $HOST
    [[ $DB_DEVICE != "" ]] && ssh_control_run_as_user root "parted $DB_DEVICE -s -- mklabel gpt mkpart ${LABEL}_D 1 -1" $HOST
    [[ $WAL_DEVICE != "" ]] && ssh_control_run_as_user root "parted $WAL_DEVICE -s -- mklabel gpt mkpart ${LABEL}_W 1 -1" $HOST
  fi
}



kolla_control_stop_containers () {
  local CONTAINERS=$1 HOST=$2
  local CONTAINER
  for CONTAINER in $CONTAINERS; do
    echo "Stopping $CONTAINERS on $HOST"
    ssh_control_run_as_user root "ID=\`docker container list|grep $CONTAINER|awk '{print \$1}'\`; [[ \$ID == \"\" ]] || docker container stop \$ID" $HOST
  done
}

kolla_control_stop_containers_these_hosts () {
  local CONTAINERS=$1 HOSTS=$2



  local ERROR HOST RETURN_CODE PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'` 'all_reaped'; do
        if [[ $PID == 'all_reaped' ]]; then
          [[ $ERROR == "" ]] && return 0 || return 1
        else
          wait ${PID} 2>/dev/null
          RETURN_CODE=$?
          if [[ $RETURN_CODE != 0 ]]; then
            echo "Return code for PID $PID: $RETURN_CODE"
            echo "Stop containers, CONTAINERS:$CONTAINERS"
            ERROR=true
          fi
        fi
      done
    else
      kolla_control_stop_containers "$CONTAINERS" $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Stopping $HOST..."
    fi
  done
}
 

# BRING DOWN STACK
#  Compute:
#    Stop the tenant VMs, Containers
#    Stop compute services
#    Shutdown compute nodes
#  Ceph:
#    Stop all Ceph clients (manila workloads, glance-api, cinder-scheduler)
#    Discover the ceph monitor...
#    Check that cluster is healthy
#    Set noout, norecover, norebalance, nobackfill, nodown, pause flags
#      ceph osd set noout
#      ceph osd set norecover
#      ceph osd set norebalance
#      ceph osd set nobackfill
#      ceph osd set nodown
#      ceph osd set pause
#    Shutdown osd nodes
#    Shutdown monitor nodes one by one
#    Shutdown admin node
#  Control:
#    Shut down each node from least to most primary (30 minute stagger?)
# NOTES: OSD / Compute nodes can shutdown together
#        Ceph Monitor / Admin and Control nodes can be shutdown together

kolla_control_shutdown_stack () {
  local CONTROL_WAIT=300

  echo "Bringing down tenant VMs and Containers"
  # kolla_control_stop_tenant_resources "$COMPUTE_HOSTS"
  echo "Bringing down Compute Services: $COMPUTE_HOSTS"
  kolla_control_stop_containers_these_hosts "centos-binary-nova-compute centos-binary-nova-libvirt centos-binary-nova-ssh" "$COMPUTE_HOSTS"

  echo "Stopping all CEPH usage"
  # kolla_control_stop_containers_these_hosts "manila-shit" "$WHICH_HOSTS"
  # kolla_control_stop_containers_these_hosts "glance-shit" "$WHICH_HOSTS"
  # kolla_control_stop_containers_these_hosts "cinder-shit" "$WHICH_HOSTS"

  echo "Readying to bring down CEPH: $OSD_HOSTS"
#  local CEPH_MON=`kolla_control_get_ceph_monitor "$CONTROL_HOSTS"`
#  local OUTPUT=`ssh_control_run_as_user stack "ceph -s" $CEPH_MON`
#  if ( grep "HEALTH_OK" "$OUTPUT" ); then
#    echo "CEPH Health is OK, proceeding..."
#    local FLAG
#    for FLAG in noout norecover norebalance nobackfill nodown pause; do
#      ssh_run_as_user stack "ceph osd set $FLAG" $CEPH_MON
#    done
#  else
#    echo "CEPH HEALTH NOT OK, Please intervene!"
#    echo "EXITING!"
#    return 1
#  fi

  echo "STOPPING COMPUTE AND CEPH NODES: `group_logic_union \"$COMPUTE_HOSTS\" \"$OSD_HOSTS\"`"
  os_control_graceful_stop_these_hosts "`group_logic_union \"$COMPUTE_HOSTS\" \"$OSD_HOST\"`"


  echo "Bringing down Control Nodes: $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS"
  local HOST
  for HOST in $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS; do
    echo "Stopping: $HOST"
    os_control_graceful_stop $HOST
    [[ $? == 0 ]] || { echo "Failed to stop Control Node: $HOST, EXITING!"; return 1; }

    echo "Control Node $HOST Stopped.  Waiting $CONTROL_WAIT seconds to proceed."
    sleep $CONTROL_WAIT
  done
}



# START THE STACK
# Control:
#    Power on nodes from most to least primary (5 minute stagger?)
# Ceph:
#    Power on the admin node
#    Power on the monitor nodes
#    Power on the osd nodes
#    Wait for all the nodes to come up , Verify all the services are up and the connectivity is fine between the nodes.
#    Unset all the noout,norecover,noreblance, nobackfill, nodown and pause flags.
#      ceph osd unset noout
#      ceph osd unset norecover
#      ceph osd unset norebalance
#      ceph osd unset nobackfill
#      ceph osd unset nodown
#      ceph osd unset pause
#    Start ceph clients (manila workloads, glance-api, cinder-scheduler)
#    Check and verify the cluster is in healthy state, Verify all the clients are able to access the cluster.
# Compute:
#   Start compute nodes
#   Start compute services
#   Start tenant VMs, Containers


kolla_control_startup_stack () {
  echo "Starting Stack..."
  local CONTROL_WAIT=300
  local HOST

  echo "Bringing up Control Nodes: $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"
  for HOST in $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS; do
    echo "Starting: $HOST"
    os_control_boot_to_target_installation default $HOST
    [[ $? == 0 ]] || {
      echo; echo "BOOT TO DEFAULT FAILED FOR $HOST.  INVESTIGATE!"
      echo "EXITING!"
      return 1
    }
    sleep $CONTROL_WAIT
  done

  echo "Bringing up Compute Nodes: $COMPUTE_HOSTS"
  os_control_boot_to_target_installation_these_hosts default "$COMPUTE_HOSTS"
}
