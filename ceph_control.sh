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

