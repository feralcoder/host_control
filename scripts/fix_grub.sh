#!/bin/bash

HOSTNAME_ABBREV=`cat /root/abbrev_hostname`
[[ $TIMEOUT != "" ]] || TIMEOUT=30

unalias cp >/dev/null 2>&1
unalias rm >/dev/null 2>&1


mount_all_boots () {
  #JUST IN CASE
  mountpoint -q /boot || mount /boot

  BOOTS=`blkid| grep _boot |  sed 's/ /\n/g' | grep "^LABEL=" | awk -F"=" '{print $2}' | sed 's/\"//g'`
  for BOOT in $BOOTS; do
    mkdir /mnt/$BOOT
    mount LABEL=$BOOT /mnt/$BOOT
  done
}

set_all_grub_nocrossboot () {
  unalias cp >/dev/null 2>&1
  BOOTS=`blkid| grep _boot |  sed 's/ /\n/g' | grep "^LABEL=" | awk -F"=" '{print $2}' | sed 's/\"//g'`
  for BOOT in $BOOTS; do
    echo "Displacing $BOOT grub config..."
    mv /mnt/$BOOT/grub2/grub.cfg /mnt/$BOOT/grub2/grub.cfg.bak_$$
    echo "Placing $BOOT no-crossboot grub config..."
    cp /mnt/$BOOT/grub2/grub.cfg.no-crossboot /mnt/$BOOT/grub2/grub.cfg
  done
}

restore_all_other_grub () {
  BOOTS=$(blkid | grep _boot | sed 's/ /\n/g' | grep "^LABEL=" | awk -F"=" '{print $2}' | sed 's/"//g')
  CURRENT_BOOT_DEV=$(mount | grep " /boot " | awk '{print $1}' | sed 's/.$//g')
  CURRENT_BOOT_LABEL=$(blkid | grep $CURRENT_BOOT_DEV | grep "_boot" | sed 's/ /\n/g' | grep '^LABEL=' | awk -F'=' '{print $2}' | sed 's/"//g')
  for BOOT in $BOOTS; do
    if [[ $BOOT == $CURRENT_BOOT_LABEL ]]; then
      echo "SKIPPING $CURRENT_BOOT_LABEL"
    else
      echo "Replacing $BOOT grub config..."
      mv -f /mnt/$BOOT/grub2/grub.cfg.bak_$$ /mnt/$BOOT/grub2/grub.cfg
    fi
  done
}

fix_timeout () {
#  Don't change default in /etc/, for now...
#  cat /etc/default/grub | sed "s/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$TIMEOUT/g" > /tmp/grub_$$ && cat /tmp/grub_$$ > /etc/default/grub

  ## DON'T REGENERATE grub.cfg, EDIT IN PLACE FOR SAFEST CHANGE
  # grub2-mkconfig -o /boot/grub2/grub.cfg
  cat /boot/grub2/grub.cfg | sed -r "s/set timeout=-*[0-9]+/set timeout=$TIMEOUT/g" > /tmp/grub.cfg_$$
  cat /tmp/grub.cfg_$$ > /boot/grub2/grub.cfg
}

fix_grub () {
  # IN CASE CURRENT ROOT/BOOT MOUNTS ARE MISMATCHED...  USE xxx_boot TO SET xxx_root.
  BOOT_DRIVE=`mount | grep "/boot " | awk '{print $1}' | sed 's/[0-9]*$//g'`
  # IOW: xxx_root
  GRUB_DEVICE_UUID=`blkid | grep -v osprober | grep _root | grep $BOOT_DRIVE | sed 's/ /\n/g' | grep '^UUID=' | awk -F'=' '{print $2}' | sed 's/"//g'`


  ### SET UP THIS BOOT DRIVE'S device.map

  # FIRST DISCOVER USB DEVICE, AND SELF DEVICE
  USB_BOOT_DEV=`blkid | grep -v osprober | grep "LABEL=\"x${HOSTNAME_ABBREV}_boot\"" | awk '{print $1}' | sed 's/://g' | sed s/[0-9]*$//g`
  if [[ $USB_BOOT_DEV == "" ]]; then
    USB_BOOT_DEV=`blkid | grep -v osprober | grep "LABEL=\"xax_boot\"" | awk '{print $1}' | sed 's/://g' | sed s/[0-9]*$//g`
  fi
  if [[ $USB_BOOT_DEV == "" ]]; then
    echo "USB_BOOT_DEV not defined!  Fix your labels!"
    exit
  fi

  SELF_DEV=`mount | grep " /boot " | awk '{print $1}' | sed s/[0-9]*$//g`

  # MAP IS ORDERED self, USB, sda, sdb, sdc..., WITHOUT REPEATS
  cat << EOF > /tmp/drives_$$
$SELF_DEV
$USB_BOOT_DEV
/dev/sda
/dev/sdb
/dev/sdc
EOF

  unalias mv >/dev/null 2>&1
  use_next () { local FIRST=`head -n 1 /tmp/drives_$$`; grep -v $FIRST /tmp/drives_$$ > /tmp/x_$$ ; mv -f /tmp/x_$$ /tmp/drives_$$ ; echo $FIRST; }

  HD0_DEV=$(use_next)
  HD1_DEV=$(use_next)
  HD2_DEV=$(use_next)

  echo "(hd0) $HD0_DEV" > /boot/grub2/device.map
  echo "(hd1) $HD1_DEV" >> /boot/grub2/device.map
  echo "(hd2) $HD2_DEV" >> /boot/grub2/device.map


  # UPDATE GRUB TITLES FOR LOCAL-BOOTING
  ROOT_LABEL=`blkid | grep -v osprober | grep $HD0_DEV | grep root | sed 's/ /\n/g' | grep LABEL | awk -F"=" '{print $2}'`
  cd /boot/
  LOADER_ENTRIES=`ls loader/entries/`
  for i in $LOADER_ENTRIES; do
      cp loader/entries/$i loader/entry_bak.$i
      sed -i "s/title .*CentOS/title $ROOT_LABEL CentOS/g" loader/entries/$i
  done

  # UPDATE GRUB: SELF-BOOT
  cp -f /etc/default/grub /etc/default/grub.orig
  sed -i "s/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/g" /etc/default/grub
  sed -i "s/ resume=.*/ noresume\"/g" /etc/default/grub

  cp -f /boot/grub2/grub.cfg /boot/grub2/grub.cfg-orig
  grub2-mkconfig -o /boot/grub2/grub.cfg
  fix_timeout

  # REMOVE hint-bios, hint-efi
  cat grub2/grub.cfg | sed 's/--hint-[^ ]*/ /g' > /tmp/grub.cfg_$$ && cat /tmp/grub.cfg_$$ > grub2/grub.cfg

  # SET NONBOOTABLE DRIVES TO hd2 (WILL BECOME BOOTABLE WHEN MOVED TO PRIMARY / SECONDARY W/O REBUILDING GRUB)
  cat grub2/grub.cfg | sed "s/'hd[3-9],/'hd2,/g" > /tmp/grub.cfg_$$ && cat /tmp/grub.cfg_$$ > grub2/grub.cfg

  # CHANGE "on /dev/sdxY" DESCRIPTIONS TO "on hdX" OR "UNBOOTABLE"
  DRIVES=`cat grub2/grub.cfg | grep \/dev\/sd | sed 's/ /\n/g' | grep \/dev\/sd | sed "s/[0-9])'//g" | sort | uniq`
  for DRIVE in $DRIVES ; do
      GRUB_DRIVE=`grep $DRIVE grub2/device.map | awk '{print $1}' | sed 's/[()]//g'`
      if [ x$GRUB_DRIVE == x ]; then
          GRUB_DRIVE=UNBOOTABLE
      fi
      cat grub2/grub.cfg | sed "s~on $DRIVE.~on $GRUB_DRIVE~g" > /tmp/grub.cfg_$$ && cat /tmp/grub.cfg_$$ > grub2/grub.cfg
  done

  grub2-install $SELF_DEV
}


mount_all_boots
set_all_grub_nocrossboot
fix_grub
restore_all_other_grub
