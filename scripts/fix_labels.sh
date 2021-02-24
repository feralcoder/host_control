#!/bin/bash

fix_labels () {
  local DEVICE=$1 LABEL_PREFIX=$2

  unalias cp &>/dev/null

  MOUNTS=`mount | grep "$DEVICE[0-9]" | awk '{print $3}'`
  for MOUNT in $MOUNTS; do umount $MOUNT; done

  sfdisk -d $DEVICE | grep -v 'label-id' | sfdisk $DEVICE
  sleep 1
  BOOT_DEV=`blkid | grep "$DEVICE" | grep boot | awk -F':' '{print $1}'`
  ROOT_DEV=`blkid | grep "$DEVICE" | grep root | awk -F':' '{print $1}'`
  HOME_DEV=`blkid | grep "$DEVICE" | grep home | awk -F':' '{print $1}'`
  SWAP_DEV=`blkid | grep "$DEVICE" | grep swap | awk -F':' '{print $1}'`
  VAR_DEV=`blkid | grep "$DEVICE" | grep var | awk -F':' '{print $1}'`

  sleep 1
  xfs_admin  -U generate -L ${LABEL_PREFIX}_boot $BOOT_DEV
  xfs_admin  -U generate -L ${LABEL_PREFIX}_root $ROOT_DEV
  xfs_admin  -U generate -L ${LABEL_PREFIX}_home $HOME_DEV
  xfs_admin  -U generate -L ${LABEL_PREFIX}_var $VAR_DEV
  mkswap $SWAP_DEV -L ${LABEL_PREFIX}_swap
  SWAP_UUID=`blkid | grep $SWAP_DEV | sed 's/ /\n/g' | grep '^UUID' | awk -F'=' '{print $2}' | sed 's/"//g'`

  mkdir /mnt/${LABEL_PREFIX}_root > /dev/null 2>&1
  mount -L ${LABEL_PREFIX}_root /mnt/${LABEL_PREFIX}_root
  sed -i "s/^.* \/boot /LABEL=${LABEL_PREFIX}_boot \/boot /g" /mnt/${LABEL_PREFIX}_root/etc/fstab
  sed -i "s/^.* \/ /LABEL=${LABEL_PREFIX}_root \/ /g" /mnt/${LABEL_PREFIX}_root/etc/fstab
  sed -i "s/^.* \/home /LABEL=${LABEL_PREFIX}_home \/home /g" /mnt/${LABEL_PREFIX}_root/etc/fstab
  sed -i "s/^.* \/var /LABEL=${LABEL_PREFIX}_var \/var /g" /mnt/${LABEL_PREFIX}_root/etc/fstab
  sed -i "s/^.* swap /LABEL=${LABEL_PREFIX}_swap none swap /g" /mnt/${LABEL_PREFIX}_root/etc/fstab
  umount /mnt/${LABEL_PREFIX}_root
}

fix_labels $1 $2
