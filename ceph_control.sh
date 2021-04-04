#!/bin/bash -x


ceph_control_get_mon () {
  local HOST MON_CONTAINER HEALTH
  for HOST in $CEPH_MON_HOSTS; do
    MON_CONTAINER=`ssh_control_run_as_user root "docker container list" $HOST | grep ' ceph-mon-' | awk '{print $1}'`
    HEALTH=`ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph -s" $HOST | grep 'health:' | grep 'HEALTH_OK\|WARN' | awk '{print $2}'`
    [[ $HEALTH != "" ]] && { echo "$HOST:$MON_CONTAINER:$HEALTH"; return 0; }
  done
  echo "Health is not OK or WARN!  Exiting."
  return 1
}

ceph_control_get_status () {
  local HOST=$1 MON_CONTAINER=$2
  STATUS=`ssh_control_run_as_user root "docker exec $MON_CONTAINER ceph -s" $HOST`
  if [[ $? == 00 ]]; then
    echo "$STATUS"
  else
    echo "Failed to fetch status: $HOST $MON_CONTAINER"
    return 1
  fi
}

ceph_control_make_ceph_bluestore_OSD_the_defunct_way () {
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




ceph_control_setup_LVM_OSD () {
  local HOST=$1 BLOCK_DEVICE=$2 SUFFIX=$3 DB_DEVICE=$4 WAL_DEVICE=$5
  # BLOCK_DEVICE=/dev/sdx       (REQUIRED)
  # SUFFIX=ANYTHING             (OPTIONAL, but required if 2+ OSD's ON SYSTEM with WAL or DB devices)
  # DB_DEVICE=/dev/sdx          (OPTIONAL, if empty DB will write to block device)
  # WAL_DEVICE=/dev/sdx         (OPTIONAL, if empty WAL will write to DB device if it exists, or block device)

  local LABEL=OSD
  [[ $SUFFIX == "" ]] || LABEL=${LABEL}_$SUFFIX
 
  ssh_control_run_as_user root "parted --script $BLOCK_DEVICE mklabel gpt mkpart primary 1MiB 100% name 1 ${LABEL}_data set 1 lvm on" $HOST
  ssh_control_run_as_user root "pvcreate -y ${BLOCK_DEVICE}1; vgcreate -y ${LABEL}_data ${BLOCK_DEVICE}1; lvcreate -y -n ${LABEL}_data -l 100%FREE ${LABEL}_data" $HOST
  
  [[ $DB_DEVICE != "" ]] && {
    ssh_control_run_as_user root "parted --script $DB_DEVICE mklabel gpt mkpart primary 1MiB 100% name 1 ${LABEL}_db set 1 lvm on" $HOST
    ssh_control_run_as_user root "pvcreate -y ${DB_DEVICE}1; vgcreate -y ${LABEL}_db ${DB_DEVICE}1; lvcreate -y -n ${LABEL}_db -l 100%FREE ${LABEL}_db" $HOST
  }
  [[ $WAL_DEVICE != "" ]] && {
    ssh_control_run_as_user root "parted --script $WAL_DEVICE mklabel gpt mkpart primary 1MiB 100% name 1 ${LABEL}_wal set 1 lvm on" $HOST
    ssh_control_run_as_user root "pvcreate -y ${WAL_DEVICE}1; vgcreate -y ${LABEL}_wal ${WAL_DEVICE}1; lvcreate -y -n ${LABEL}_wal -l 100%FREE ${LABEL}_wal" $HOST
  }
}



# WARNING: /dev/xxx CAN CHANGE ACROSS REBOOT!!!
#  verify by UUID
ceph_control_show_map () {
echo 'neo:OSD_1_db:/dev/sde:51072BFB-B7A2-4ADD-9489-F932AE509D0E
neo:OSD_1_data:/dev/sdc:3412ECBA-40C5-4633-BA12-24FA57841CCE
bmn:OSD_1_db:/dev/sde:067BC4D8-6791-43E9-A23F-F456D50D2B0C
bmn:OSD_1_data:/dev/sdd:844386A8-DB43-40AA-B947-A3348A00E4A2
kgn:OSD_1_db:/dev/sdg:264058DA-DAA3-4E97-BA7F-B5A2F5E3FA61
kgn:OSD_1_data:/dev/sdf:FC563395-D751-4C88-9B87-A6992AC5589D
lmn:OSD_1_db:/dev/sde:1BDD2355-3776-48FF-A704-87C49BD8333E
lmn:OSD_1_data:/dev/sdd:676E27B6-057F-460D-B6A8-960B7E590A03
mtn:OSD_1_db:/dev/sde:5DF26BAA-0185-4F57-8763-DB5378711819
mtn:OSD_1_data:/dev/sdd:2ABBF474-5FAC-482A-9F2E-C6061790B505'
}


ceph_control_create_LVM_OSDs_from_map () {
  local OSD_MAP=$1 HOST=$2
  
  local MAPLINE HOST VG DEV UUID DRIVES DRIVE
  for MAPLINE in $OSD_MAP; do
    if ( echo $MAPLINE | grep "^$HOST:" ); then
      DRIVES=`ssh_control_run_as_user root "ls /dev/sd?" $HOST | grep '/dev/'`
      VG=`echo $MAPLINE | awk -F':' '{print $2}'`
      # ORIG DEV MAY NOT BE CURRENT DEV
      #DEV=`echo $MAPLINE | awk -F':' '{print $3}'`
      UUID=`echo $MAPLINE | awk -F':' '{print $4}'`
      DEV=$(for DRIVE in $DRIVES; do
        ( ssh_control_run_as_user root "fdisk -l $DRIVE" $HOST | grep $UUID >/dev/null ) && echo $DRIVE
      done)
  
      echo "CREATING ON $HOST: $VG $DEV $UUID"
      ssh_control_run_as_user root "pvcreate -y ${DEV}1; vgcreate -y $VG ${DEV}1; lvcreate -y -n $VG -l 100%FREE $VG" $HOST
    fi
  done
}

ceph_control_create_LVM_OSDs_from_map_these_hosts () {
  local OSD_MAP=$1 HOSTS=$2
  
  local HOST
  for HOST in $HOSTS; do
    ceph_control_create_LVM_OSDs_from_map "$OSD_MAP" $HOST
  done
}

ceph_control_wipe_LVM_OSDs_from_map () {
  local OSD_MAP=$1 HOST=$2
  
  local MAPLINE HOST VG DEV UUID DRIVES DRIVE
  for MAPLINE in $OSD_MAP; do
    if ( echo $MAPLINE | grep "^$HOST:" ); then
      DRIVES=`ssh_control_run_as_user root "ls /dev/sd?" $HOST | grep '/dev/'`
      VG=`echo $MAPLINE | awk -F':' '{print $2}'`
      # ORIG DEV MAY NOT BE CURRENT DEV
      #DEV=`echo $MAPLINE | awk -F':' '{print $3}'`
      UUID=`echo $MAPLINE | awk -F':' '{print $4}'`
      DEV=$(for DRIVE in $DRIVES; do
        ( ssh_control_run_as_user root "fdisk -l $DRIVE" $HOST | grep $UUID >/dev/null ) && echo $DRIVE
      done)
  
      echo "REMOVING ON $HOST: $VG $DEV $UUID"
      ssh_control_run_as_user root "lvremove -y $VG" $HOST
      ssh_control_run_as_user root "vgremove -y $VG" $HOST
      ssh_control_run_as_user root "pvremove -y ${DEV}1" $HOST
      ssh_control_run_as_user root "dd bs=1M count=1024 conv=sync if=/dev/zero of=${DEV}1" $HOST
    fi
  done
}

ceph_control_wipe_LVM_OSDs_from_map_these_hosts () {
  local OSD_MAP=$1 HOSTS=$2
  
  local HOST
  for HOST in $HOSTS; do
    ceph_control_wipe_LVM_OSDs_from_map "$OSD_MAP" $HOST
  done
}

ceph_control_map_OSDs () {
  local HOST=$1
  local OSDS VGS PV_VG_MAP

  OSD_VOLS=`ssh_control_run_as_user root "lvdisplay" $HOST | grep OSD_ | grep 'LV Path'`
  VGS=`echo "$OSD_VOLS" | awk '{print $3}' | awk -F'/' '{print $3}'`
  PV_VG_MAP=`ssh_control_run_as_user root "pvdisplay -C --separator '  |  ' -o pv_name,vg_name" $HOST | grep '/dev/'`

  local DEVICE
  PV_UUID_MAP=$(for PV in $(echo "$PV_VG_MAP" | awk '{print $1}'); do 
    DEVICE=$( echo $PV | sed 's/[0-9]$//g' )
    UUID=$( ssh_control_run_as_user root "fdisk -l $DEVICE" $HOST | grep "Disk identifier:" | awk '{print $3}')
    echo $PV $UUID
  done)

  for VG in $VGS; do
    PV=$(echo "$PV_VG_MAP" | grep $VG | awk '{print $1}')
    DEVICE=$(echo $PV | sed 's/[0-9]$//g')
    UUID=$(echo "$PV_UUID_MAP" | grep $DEVICE | awk '{print $2}')
    echo $HOST:$VG:$DEVICE:$UUID
  done
}



ceph_control_map_OSDs_these_hosts () {
  local HOSTS=$1
  local HOST



  local ERROR RETURN_CODE PIDS=""
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
            echo "map OSDs, no more info available"
            ERROR=true
          fi
        fi
      done
    else
      ceph_control_map_OSDs $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Getting OSD map for $HOST" >&2
    fi
  done
}
