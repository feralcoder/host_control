#!/bin/bash -x


KOLLA_CHECKOUT=/home/cliff/CODE/feralcoder/kolla-ansible
KOLLA_VENV=/home/cliff/CODE/venvs/kolla-ansible
ANSIBLE_CONTROLLER=dmb


kolla_control_start_containers () {
  local CONTAINERS=$1 HOST=$2
  echo "Stopping $CONTAINERS on $HOST"
  ssh_control_run_as_user root "docker container start $CONTAINERS" $HOST
}

kolla_control_stop_containers () {
  local CONTAINERS=$1 HOST=$2
  echo "Stopping $CONTAINERS on $HOST"
  ssh_control_run_as_user root "docker container stop $CONTAINERS" $HOST
}

kolla_control_stop_containers_by_grep_these_hosts () {
  local CONTAINERS=$1 HOSTS=$2
  local CONTAINER
  for CONTAINER in $CONTAINERS; do
    echo "Stopping $CONTAINER on $HOST"
    ssh_control_run_as_user_these_hosts root "ID=\`docker container list|grep $CONTAINER|awk '{print \$1}'\`; [[ \$ID == \"\" ]] || docker container stop \$ID" "$HOSTS"
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
 

kolla_control_start_containers_these_hosts () {
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
            echo "Start containers, CONTAINERS:$CONTAINERS"
            ERROR=true
          fi
        fi
      done
    else
      kolla_control_start_containers "$CONTAINERS" $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Stopping $HOST..."
    fi
  done
}
 

kolla_control_check_mariadb_synced_these_hosts () {
  local HOSTS=$1

  local SQL_FILE=/tmp/x_$$ COMM_FILE=/tmp/y_$$
  local HOST PASS STATE ERROR OUTPUT
  echo "SHOW STATUS LIKE 'wsrep_local_state_comment';" > $SQL_FILE
  OUTPUT=`ssh_control_sync_as_user_these_hosts root $SQL_FILE $SQL_FILE "$CONTROL_HOSTS"`
  for HOST in $CONTROL_HOSTS; do
    PASS=`ssh_control_run_as_user root "docker exec -u root  mariadb cat /etc/my.cnf | grep wsrep_sst_auth" mrl | grep wsrep | awk -F':' '{print $2}'`
    echo "mysql --password=$PASS < $SQL_FILE" > $COMM_FILE
    ssh_control_sync_as_user root $COMM_FILE $COMM_FILE $HOST
    OUTPUT=`ssh_control_run_as_user root "chmod 755 $COMM_FILE; docker cp $COMM_FILE mariadb:$COMM_FILE; docker cp $SQL_FILE mariadb:$SQL_FILE" $HOST`
    STATE=`ssh_control_run_as_user root "docker exec -u root mariadb bash $COMM_FILE" $HOST | grep wsrep_local_state_comment | awk '{print $2}'`
    [[ $STATE == "Synced" ]] || ERROR=true
  done
  [[ $ERROR == "" ]] || return 1
}

kolla_control_stop_mariadb_these_hosts () {
  local HOSTS=$1
  local HOST
  for HOST in $HOSTS; do 
    ssh_control_run_as_user root "docker stop mariadb" $HOST
    sleep 10
  done
}







kolla_control_recover_galera () {
  ssh_control_run_as_user cliff "$KOLLA_CHECKOUT/admin-scripts/utility/recover_galera.sh" $ANSIBLE_CONTROLLER || return 1
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
  local CONTROL_WAIT=20

  echo "Bringing down tenant VMs and Containers"
  # kolla_control_stop_tenant_resources "$COMPUTE_HOSTS"

  echo "Bringing down Compute Services"
  kolla_control_stop_containers_these_hosts "nova_compute nova_libvirt nova_ssh" "$COMPUTE_HOSTS"
  kolla_control_stop_containers_these_hosts "nova_novncproxy nova_conductor nova_api nova_scheduler placement_api" "$CONTROL_HOSTS"

  echo "Bringing down Network Services"
  kolla_control_stop_containers_these_hosts "neutron_openvswitch_agent openvswitch_vswitchd openvswitch_db" "$CLOUD_HOSTS"
  kolla_control_stop_containers_these_hosts "neutron_server neutron_dhcp_agent neutron_l3_agent neutron_metadata_agent" "$CONTROL_HOSTS"

  echo "Stopping Keepalived"
  kolla_control_stop_containers_these_hosts "keepalived" "$CONTROL_HOSTS"

  echo "Bringing down Metrics and Dashboard Services"
  # grafana not on all controllers...
  kolla_control_stop_containers_these_hosts "grafana gnocchi_metricd gnocchi_api horizon keystone keystone_fernet keystone_ssh kibana heat_engine heat_api_cfn heat_api elasticsearch_curator elasticsearch" "$CONTROL_HOSTS"

  echo "Stopping all CEPH usage"
  kolla_control_stop_containers_these_hosts "cinder_volume cinder_backup" "$COMPUTE_HOSTS"
  kolla_control_stop_containers_these_hosts "cinder_scheduler cinder_api glance_api" "$CONTROL_HOSTS"
  kolla_control_stop_containers_by_grep_these_hosts "ceph-osd-" "$OSD_HOSTS"
  kolla_control_stop_containers_by_grep_these_hosts "ceph-mds-" "$CONTROL_HOSTS"

  echo "Readying Ceph Cluster for Shutdown"
  local MON MON_HOST MON_CONTAINER MON_HEALTH SETTING
  MON=`ceph_control_get_mon`
  MON_HOST=`echo $MON | awk -F':' '{print $1}'`
  MON_CONTAINER=`echo $MON | awk -F':' '{print $2}'`
  MON_HEALTH=`echo $MON | awk -F':' '{print $3}'`

  ( echo $MON_HEALTH | grep 'HEALTH_OK\|HEALTH_WARN' ) && {
    for SETTING in noout norecover norebalance nobackfill nodown pause; do
      echo "ceph osd set $SETTING"
      ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd set $SETTING" $MON_HOST
    done
  } || {
    echo "CEPH CLUSTER HEALTH NOT OK!"
    echo $MON_HOST $MON_CONTAINER $MON_HEALTH
    ceph_control_get_status $MON_HOST $MON_CONTAINER
    echo "Investigate.  Exiting."
    return 1
  }

  echo "STOPPING COMPUTE AND CEPH NODES: `group_logic_union \"$COMPUTE_HOSTS\" \"$OSD_HOSTS\"`"
  os_control_graceful_stop_these_hosts "`group_logic_union \"$COMPUTE_HOSTS\" \"$OSD_HOST\"`"


  echo "STOPPING MARIADB"
  ( kolla_control_check_mariadb_synced_these_hosts "$CONTROL_HOSTS" ) || {
    echo "MariaDB is not sync'd, sleeping 20..."
    sleep 20
    ( check_mariadb_synced "$CONTROL_HOSTS" ) || {
      echo "MariaDB Still Not Sync'd. Exiting."
      return 1
    }
  }
  kolla_control_stop_mariadb_these_hosts "$TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS"


  echo "Bringing down Control Nodes: $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS"
  local HOST
  for HOST in $TERNARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $PRIMARY_CONTROL_HOSTS; do
    echo "Stopping: $HOST"
    os_control_graceful_stop $HOST
    [[ $? == 0 ]] || { echo "Failed to stop Control Node: $HOST, EXITING!"; return 1; }

    echo "Control Node $HOST Stopped.  Waiting $CONTROL_WAIT seconds to proceed."
    sleep $CONTROL_WAIT
  done

  echo; echo "CLUSTER IS SHUT DOWN"
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
  local CONTROL_WAIT=60  # This applies AFTER each host has booted to OS...
  local HOST

  # Start control nodes
  echo "Bringing up Control Nodes: $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"
  for HOST in $PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS; do
    echo "Starting: $HOST"
    # os_control_boot_to_target_installation default $HOST
    ilo_power_on $HOST
    [[ $? == 0 ]] || {
      echo; echo "BOOT TO DEFAULT FAILED FOR $HOST.  INVESTIGATE!"
      echo "EXITING!"
      return 1
    }
    sleep $CONTROL_WAIT
  done

  ssh_control_wait_for_host_up_these_hosts "$CONTROL_HOSTS" || return 1
  
  # GALERA SEEMS TO NEED RECOVERY EVERY TIME, FIGURE THIS OUT
  echo; echo "Starting keepalived, haproxy, for galera."
  kolla_control_start_containers_these_hosts "haproxy keepalived" "$CONTROL_HOSTS"
  echo; echo "Recovering galera DB cluster."
  kolla_control_recover_galera || return 1

  echo "Bringing up Compute and OSD Nodes: `group_logic_union \"$COMPUTE_HOSTS\" \"$OSD_HOST\"`"
  os_control_boot_to_target_installation_these_hosts default "`group_logic_union \"$COMPUTE_HOSTS\" \"$OSD_HOST\"`" || return 1
  sleep 60


  # Discover ceph mon host.  Enable cluster for balancing and recovery.  Or exit if unhealthy.
  echo "READYING CEPH CLUSTER FOR ACTION"
  local MON MON_HOST MON_CONTAINER MON_HEALTH SETTING
  echo "Discovering active ceph mon host and daemon."
  MON=`ceph_control_get_mon`
  MON_HOST=`echo $MON | awk -F':' '{print $1}'`
  MON_CONTAINER=`echo $MON | awk -F':' '{print $2}'`
  MON_HEALTH=`echo $MON | awk -F':' '{print $3}'`

  ( echo $MON_HEALTH | grep 'HEALTH_OK\|HEALTH_WARN' ) && {
    for SETTING in noout norecover norebalance nobackfill nodown pause; do
      echo "ceph osd unset $SETTING"
      ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph osd unset $SETTING" $MON_HOST || return 1
    done
  } || {
    echo "CEPH CLUSTER HEALTH NOT OK!"
    echo $MON_HOST $MON_CONTAINER $MON_HEALTH
    ceph_control_get_status $MON_HOST $MON_CONTAINER
    echo "Investigate.  Exiting."
    return 1
  }


  # START ALL STOPPED CONTAINERS EVERYWHERE...
  echo; echo "Starting all stopped containers everywhere."
  ssh_control_run_as_user_these_hosts root "docker container ls --format '{{.Names}}' --filter status=exited | awk '{print \$1}' | grep -v CONTAINER | xargs -r docker start 2>&1" "$STACK_HOSTS"
}
