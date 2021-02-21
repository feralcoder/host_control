#!/bin/bash

dynamic_clone () {
  local SRC_DEV=$1 DEST_DEV=$2

  # DUPLICATE DRIVE'S PARTITIONS (but strip label-id)
  sfdisk -l -d $SRC_DEV | grep -v 'label-id' | sfdisk $DEST_DEV
  local SRC_PARTS=`blkid | grep $SRC_DEV | awk '{print $1}' | sed 's/://g'`
  for SRC_PART in $SRC_PARTS; do
      local DEST_PART=`echo $SRC_PART | sed "s.$SRC_DEV.$DEST_DEV.g"`
      local TYPE=`blkid | grep $SRC_PART | sed 's/ /\n/g' | grep '^TYPE' | awk -F'=' '{print $2}' | sed 's/"//g'`
      echo $SRC_PART $TYPE
      local LABEL FEATURES
      case x$TYPE in
        xext4)
          LABEL=`tune2fs -l $SRC_PART | grep 'Filesystem volume name' | awk -F':' '{print $2}' | sed 's/ //g'`
          FEATURES=`tune2fs -l $SRC_PART | grep 'Filesystem features' | awk -F':' '{print $2}' | sed 's/^ *//g' | sed 's/ /,/g'`
          echo y | mke2fs -j -O $FEATURES -L z$LABEL $DEST_PART
          ;;
        xxfs)
          LABEL=`xfs_admin -l $SRC_PART | awk -F'=' '{print $2}' | sed 's/[ "]//g'`
          mkfs.xfs -f -L z$LABEL $DEST_PART
          ;;
        xswap)
          LABEL=`swaplabel $SRC_PART | grep LABEL | awk -F':' '{print $2}' | sed 's/ //g'`
          mkswap -L z$LABEL $DEST_PART
          ;;
        *)
          echo "UNEXPECTED BLOCK DEVICE TYPE $TYPE"
          ;;
      esac
  done
  
  # SYNC CONTENTS OF EACH FS
  mkdir /mnt/src_$$ /mnt/dest_$$
  for SRC_PART in $SRC_PARTS; do
      DEST_PART=`echo $SRC_PART | sed "s.$SRC_DEV.$DEST_DEV.g"`
      TYPE=`blkid | grep $SRC_PART | sed 's/ /\n/g' | grep TYPE | awk -F'=' '{print $2}' | sed 's/"//g'`
      echo $TYPE
      case x$TYPE in
        xext4 | xxfs)
          mount $SRC_PART /mnt/src_$$
          mount $DEST_PART /mnt/dest_$$
          rsync -avxHAX /mnt/src_$$/ /mnt/dest_$$/
          umount /mnt/src_$$
          umount /mnt/dest_$$
          ;;
        xswap)
          echo Swap is synced, you are welcome.
          ;;
        *)
          echo "UNEXPECTED BLOCK DEVICE TYPE $TYPE"
          ;;
      esac
  done
  rmdir /mnt/src_$$ /mnt/dest_$$
}

noalias cp
dynamic_clone $1 $2
