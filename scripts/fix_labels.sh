#!/bin/bash

fix_labels () {
  local DEVICE=$1 LABEL_PREFIX=$2

  unalias cp &>/dev/null

  BOOT_DEV=`blkid | grep "$DEVICE" | grep boot | awk -F':' '{print $1}'`
  HOME_DEV=`blkid | grep "$DEVICE" | grep home | awk -F':' '{print $1}'`
  SWAP_DEV=`blkid | grep "$DEVICE" | grep swap | awk -F':' '{print $1}'`
  ROOT_DEV=`blkid | grep "$DEVICE" | grep root | awk -F':' '{print $1}'`
  VAR_DEV=`blkid | grep "$DEVICE" | grep var | awk -F':' '{print $1}'`

  xfs_admin  -L ${LABEL_PREFIX}_home $HOME_DEV
  xfs_admin  -L ${LABEL_PREFIX}_root $ROOT_DEV
  xfs_admin  -L ${LABEL_PREFIX}_var $VAR_DEV
  swaplabel $SWAP_DEV -L ${LABEL_PREFIX}_swap
  xfs_admin  -L ${LABEL_PREFIX}_boot $BOOT_DEV
}

fix_labels $1 $2
