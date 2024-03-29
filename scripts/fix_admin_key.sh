#!/bin/bash

# DEFINE
DRIVE_PREFIX=x
DEVICE=$1
HOSTNAME_ABBREV=$2
HOSTNAME=$3

#### SO MANY FUCKING PROBLEMS
# From passing only short name.
# If only 2 args, figure out from existing hostname.
[[ $HOSTNAME != "" ]] || {
  UNQUALIFIED_NAME=`hostname | awk -F'.' '{print $1}'`
  SIMPLE_NAME=`echo $UNQUALIFIED_NAME | awk -F'-' '{print $1}'`
  HOSTNAME=$SIMPLE_NAME
}

unalias cp >/dev/null 2>&1

HOSTNAME_ADMIN=${HOSTNAME}-admin
LABEL_PREFIX=${DRIVE_PREFIX}${HOSTNAME_ABBREV}

# MOUNT USB ROOT
ROOT_LABEL=${LABEL_PREFIX}_root
ROOT_MOUNT=/mnt/$ROOT_LABEL
mkdir $ROOT_MOUNT >/dev/null 2>&1
mountpoint $ROOT_MOUNT || mount LABEL=$ROOT_LABEL $ROOT_MOUNT

# UPDATE ADMIN STICK'S IP, FSTAB, HOSTNAME, HOST_KEYS
cd $ROOT_MOUNT/etc

fix_networking () {
  # UPDATE IP, ACTIVATE ENO2 - THIS WON'T BE UNDONE BY GENERIC STICK SETUP COMMMANDS - SED WON'T MATCH...
  LAST_OCTET=`ip addr|grep 192.168.1[0-9]*\. | grep '192.168.127.255' | awk '{print $2}' | awk -F'.' '{print $4}' | awk -F'/' '{print $1}'`

  if [[ $(ls sysconfig/network-scripts | grep ifcfg-eno) ]]; then
    FIRST_IF=`ls sysconfig/network-scripts/ifcfg-eno1 | awk -F'/' '{print $3}'`
  elif [[ $(ls sysconfig/network-scripts | grep ifcfg-enp) ]]; then
    FIRST_IF=`ls sysconfig/network-scripts/ifcfg-enp*f0 | awk -F'/' '{print $3}'`
  else
    echo "Cannot determine interfaces!"
    ls sysconfig/network-scripts/
    exit
  fi

  cp -f sysconfig/network-scripts/${FIRST_IF} sysconfig/network-scripts/orig-${FIRST_IF} 
  cat sysconfig/network-scripts/${FIRST_IF} | grep -v 'IPV6' | sed "s/IPADDR.*/IPADDR='192.168.127.${LAST_OCTET}'/g" | sed "s/GATEWAY.*/GATEWAY='192.168.127.241'/g" > /tmp/${FIRST_IF}_$$ && cat /tmp/${FIRST_IF}_$$ > sysconfig/network-scripts/${FIRST_IF}
}

fix_networking


# UPDATE FSTAB TO USE LABELS
cp -f fstab fstab.orig
cat fstab | sed "s/^.* \/boot /LABEL=${LABEL_PREFIX}_boot \/boot /g" | sed "s/^.* \/ /LABEL=${LABEL_PREFIX}_root \/ /g" | sed "s/^.* \/home /LABEL=${LABEL_PREFIX}_home \/home /g" | sed "s/^.* swap/LABEL=${LABEL_PREFIX}_swap swap swap/g" > /tmp/fstab_$$ && cat /tmp/fstab_$$ > fstab

# UPDATE HOSTNAME
cp -f hostname hostname.orig
cat hostname | sed "s/xxxaaaxxx/${HOSTNAME_ADMIN}/g" > /tmp/hostname_$$ && cat /tmp/hostname_$$ > hostname

# PRESERVE HOST_KEYS
rsync -av /etc/ssh/ssh_host_* ssh/
chmod 600 ssh/ssh_host_*

# DONE!  (done?)
cd / && umount $ROOT_MOUNT


# MOUNT USB BOOT
BOOT_LABEL=${LABEL_PREFIX}_boot
BOOT_MOUNT=/mnt/$BOOT_LABEL
mkdir $BOOT_MOUNT >/dev/null 2>&1
mountpoint $BOOT_MOUNT || mount LABEL=$BOOT_LABEL $BOOT_MOUNT
cd $BOOT_MOUNT

echo "(hd0) $DEVICE" > grub2/device.map
echo "(hd1) /dev/sda" >> grub2/device.map

# UPDATE GRUB TITLES FOR LOCAL-BOOTING ON ADMIN DRIVE
LOADER_ENTRIES=`ls loader/entries/`
for i in $LOADER_ENTRIES; do
    cp loader/entries/$i loader/entry_bak.$i
    sed -i "s/title .*CentOS/title \"${LABEL_PREFIX}_root\" CentOS/g" loader/entries/$i
done

cd / && umount $BOOT_MOUNT
