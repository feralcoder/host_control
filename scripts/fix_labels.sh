#!/bin/bash

fix_labels () {
  local DEVICE=$1 LABEL_PREFIX=$2

  unalias cp >/dev/null 2>&1

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


  BOOT_MOUNT=/mnt/${LABEL_PREFIX}_boot
  mount -L ${LABEL_PREFIX}_boot $BOOT_MOUNT
  # UPDATE GRUB TITLES FOR LOCAL-BOOTING
  BOOT_LABEL=`blkid | grep -v osprober | grep $DEVICE | grep boot | sed 's/ /\n/g' | grep LABEL | awk -F"=" '{print $2}'`
  cd $BOOT_MOUNT
  LOADER_ENTRIES=`ls loader/entries/`
  for i in $LOADER_ENTRIES; do
      cp loader/entries/$i loader/entry_bak.$i
      sed -i "s/title .*CentOS/title $BOOT_LABEL CentOS/g" loader/entries/$i
  done
  umount $BOOT_MOUNT


}

fix_labels $1 $2
