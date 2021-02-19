#!/bin/bash

UNDERCLOUD_HOST=dmb
UNDERCLOUD_IP=`getent ahosts $UNDERCLOUD_HOST | awk '{print $1}' | tail -n 1`


stack_control_make_restore_script () {
  # SRC=/backups/stack_dumps/dumbledore_02_Ussuri_Undercloud
  # DEST=[akgn|bdmb|etc]
  local HOST=$1 SRC=$2 DEST=$3

cat << EOF > /tmp/restore_undercloud.sh_$$
#!/bin/bash

for mount in boot root home var; do
  mkdir /mnt/${DEST}_\${mount}
  mount LABEL=${DEST}_\${mount} /mnt/${DEST}_\${mount}
  rmdir /mnt/${DEST}_\${mount}
done

SOURCE_PATH=$SRC/${HOST}
DEST_PATH=/mnt/$DEST

rsync -avxHAX \${SOURCE_PATH}_root/ \${DEST_PATH}_root/ --exclude='/etc/fstab*' --exclude='/etc/default/grub*' --delete
rsync -avxHAX \${SOURCE_PATH}_home/ \${DEST_PATH}_home/ --delete
rsync -avxHAX \${SOURCE_PATH}_var/ \${DEST_PATH}_var/ --delete
rsync -avxHAX \${SOURCE_PATH}_boot/  \${DEST_PATH}_boot/ --exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*' --delete

EOF

echo /tmp/restore_undercloud.sh_$$
}




stack_control_make_backup_script () {
  # SRC=[admb|bkgn|etc]
  # DEST=/backups/undercloud_dumps/
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  local HOST=$1 SRC=$2 DEST=$3 BACKUPLINK=$4

cat << EOF > /tmp/backup_undercloud.sh_$$
#!/bin/bash

for mount in boot root home var; do
  mkdir /mnt/${SRC}_\${mount}
  mount LABEL=${SRC}_\${mount} /mnt/${SRC}_\${mount}
  rmdir /mnt/${SRC}_\${mount}
done

SOURCE_PATH=/mnt/$SRC
DEST_PATH=$DEST/${HOST}_$NOW

mkdir \$DEST_PATH
rsync -avxHAX \${SOURCE_PATH}_root/ \${DEST_PATH}/${HOST}_root/ --exclude='/etc/fstab*' --exclude='/etc/default/grub*' --delete
rsync -avxHAX \${SOURCE_PATH}_home/ \${DEST_PATH}/${HOST}_home/ --delete
rsync -avxHAX \${SOURCE_PATH}_var/ \${DEST_PATH}/${HOST}_var/ --delete
rsync -avxHAX \${SOURCE_PATH}_boot/  \${DEST_PATH}/${HOST}_boot/ --exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*' --delete

EOF

if [[ $BACKUPLINK != "" ]]; then
cat << EOF >> /tmp/backup_undercloud.sh_$$
rm $DEST/$BACKUPLINK
ln -s \$DEST_PATH $DEST/$BACKUPLINK
EOF
fi

echo /tmp/backup_undercloud.sh_$$
}





stack_control_restore () {
  # SRC=/backups/undercloud_dumps/dumbledore_02_Ussuri_Undercloud
  # DEST=[admb|bkgn|etc]
  # FINAL_TARGET=[admin|default]
  local HOST=$1 SRC=$2 DEST=$3 FINAL_TARGET=$4

  local NOW=`date +%Y%m%d-%H%M`

  os_control_boot_to_target_installation admin $HOST
  if [[ $? != 0 ]]; then
    echo "Failed to boot $HOST to ADMIN!"
    return 1
  fi

  local SCRIPT=`stack_control_make_restore_script $HOST $SRC $DEST`
  ssh_control_sync_as_user root $SCRIPT /root/undercloud_restore_${NOW}.sh dmb
  ssh_control_run_as_user root "chmod 755 /root/undercloud_restore_${NOW}.sh" dmb
  SYNC_OUTPUT=$(ssh_control_run_as_user root "/root/undercloud_restore_${NOW}.sh" dmb)

  echo "$SYNC_OUTPUT" > /tmp/restore_output_$$.log
  ssh_control_sync_as_user root /tmp/restore_output_$$.log /root/restore_output_$NOW.log dmb
 
  if [[ $FINAL_TARGET == "default" ]]; then
    os_control_boot_to_target_installation default $HOST
    if [[ $? != 0 ]]; then
      echo "Failed to boot $HOST to DEFAULT!"
      return 1
    fi
  fi
}



stack_control_backup () {
  # SRC=[admb|bkgn|etc]
  # DEST=/backups/undercloud_dumps/
  # FINAL_TARGET=[admin|default]
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  local HOST=$1 SRC=$2 DEST=$3 FINAL_TARGET=$4 BACKUPLINK=$5

  local NOW=`date +%Y%m%d-%H%M`

  os_control_boot_to_target_installation admin $HOST
  if [[ $? != 0 ]]; then
    echo "Failed to boot $HOST to ADMIN!"
    return 1
  fi

  local SCRIPT=`stack_control_make_backup_script $HOST $SRC $DEST $BACKUPLINK`
  ssh_control_sync_as_user root $SCRIPT /root/undercloud_backup_${NOW}.sh dmb
  ssh_control_run_as_user root "chmod 755 /root/undercloud_backup_${NOW}.sh" dmb
  SYNC_OUTPUT=$(ssh_control_run_as_user root "/root/undercloud_backup_${NOW}.sh" dmb)

  echo "$SYNC_OUTPUT" > /tmp/backup_output_$$.log
  ssh_control_sync_as_user root /tmp/backup_output_$$.log /root/backup_output_$NOW.log dmb


  if [[ $FINAL_TARGET == "default" ]]; then
    os_control_boot_to_target_installation default $HOST
    if [[ $? != 0 ]]; then
      echo "Failed to boot $HOST to DEFAULT!"
      return 1
    fi
  fi
}



stack_control_backup_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  stack_control_backup dmb bdmb /backups/undercloud_dumps default $BACKUPLINK
}

stack_control_restore_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  stack_control_restore dmb /backups/undercloud_dumps/$BACKUPLINK bdmb
}

stack_control_build_the_whole_fucking_thing () {
  local HOST=$1

  stack_control_restore dmb admb /backups/undercloud_dumps/dumbledore_01_CentOS_8 default
  ssh_control_run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_undercloud.sh" dmb
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_undercloud.sh" dmb)
  # [[ $OUTPUT == "UNDERCLOUD OK" ]] || { echo "Undercloud installation incomplete, check it out!"; return 1; }
  stack_control_backup dmb admb /backups/undercloud_dumps default new-dumbledore_02_Ussuri_Undercloud
  ssh_control_run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_overcloud.sh" dmb
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_overcloud.sh" dmb)
  # [[ $OUTPUT == "OVERCLOUD OK" ]] || { echo "Overcloud installation incomplete, check it out!"; return 1; }
  stack_control_backup dmb admb /backups/undercloud_dumps default new-dumbledore_03_Ussuri_Overcloud
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

  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
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
