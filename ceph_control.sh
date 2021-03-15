#!/bin/bash -x



ceph_control_setup_OSD () {
  local HOST=$1 BLOCK_DEVICE=$2 SUFFIX=$3 DB_DEVICE=$4 WAL_DEVICE=$5
  # BLOCK_DEVICE=/dev/sdx       (REQUIRED)
  # SUFFIX=ANYTHING             (OPTIONAL, but required if 2+ OSD's ON SYSTEM with WAL or DB devices)
  # DB_DEVICE=/dev/sdx          (OPTIONAL, if empty DB will write to block device)
  # WAL_DEVICE=/dev/sdx         (OPTIONAL, if empty WAL will write to DB device if it exists, or block device)

  local LABEL=OSD
  [[ $SUFFIX == "" ]] || LABEL=${LABEL}_$SUFFIX
 
  COMMAND="parted --script $DEVICE mklabel gpt mkpart primary 1MiB 100% name 1 $LABEL set 1 lvm on"
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
echo 'mtn:OSD_1_db:/dev/sde:5DF26BAA-0185-4F57-8763-DB5378711819
mtn:OSD_1_data:/dev/sdd:2ABBF474-5FAC-482A-9F2E-C6061790B505
lmn:OSD_1_db:/dev/sde:1BDD2355-3776-48FF-A704-87C49BD8333E
lmn:OSD_1_data:/dev/sdd:676E27B6-057F-460D-B6A8-960B7E590A03
bmn:OSD_1_db:/dev/sde:632DFF71-2758-4DB2-8092-D525BA42A58C
bmn:OSD_1_data:/dev/sdd:8877C770-20BD-4826-BB74-511AF41D7AD2
neo:OSD_1_db:/dev/sde:A784A191-2CEC-49AF-B8A9-6F590F615299
neo:OSD_1_data:/dev/sdc:9CBA2B15-FB1E-4AF8-8BFF-8AE8558F27BA
kgn:OSD_1_db:/dev/sdg:F0C24FA2-BFE0-4445-AE10-05D68E31A13B
kgn:OSD_1_data:/dev/sdf:6DFC0E9F-2411-4084-A069-968E766E6F6F'
}


ceph_control_wipe_OSDs () {
  local OSD_MAP=$1
  
  local MAPLINE HOST VG DEV UUID DRIVES DRIVE
  for MAPLINE in $OSD_MAP; do
    HOST=`echo $MAPLINE | awk -F':' '{print $1}'`
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

  local RETURN_CODE PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "map OSDs, no more info available"
        fi
      done
    else
      ceph_control_map_OSDs $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Getting OSD map for $HOST" >&2
    fi
  done
}
