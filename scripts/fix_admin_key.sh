#!/bin/bash

# DEFINE
DRIVE_PREFIX=x
DEVICE=$1
HOSTNAME_ABBREV=$2
HOSTNAME=$3

unalias cp &>/dev/null

HOSTNAME_ADMIN=${HOSTNAME}-admin
LABEL_PREFIX=${DRIVE_PREFIX}${HOSTNAME_ABBREV}

# MOUNT USB ROOT
mkdir /mnt/${LABEL_PREFIX}_root
mount LABEL=${LABEL_PREFIX}_root /mnt/${LABEL_PREFIX}_root

# UPDATE ADMIN STICK'S IP, FSTAB, HOSTNAME, HOST_KEYS
cd /mnt/${LABEL_PREFIX}_root/etc

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
cp /etc/ssh/ssh_host_* ssh/
chmod 600 ssh/ssh_host_*

# DONE!  (done?)
cd / && umount /mnt/${LABEL_PREFIX}_root


# MOUNT USB BOOT
mkdir /mnt/${LABEL_PREFIX}_boot
mount LABEL=${LABEL_PREFIX}_boot /mnt/${LABEL_PREFIX}_boot
cd /mnt/${LABEL_PREFIX}_boot

echo "(hd0) $DEVICE" > grub2/device.map
echo "(hd1) /dev/sda" >> grub2/device.map

# UPDATE GRUB TITLES FOR LOCAL-BOOTING ON ADMIN DRIVE
LOADER_ENTRIES=`ls loader/entries/`
for i in $LOADER_ENTRIES; do
    cp loader/entries/$i loader/entry_bak.$i
    cat loader/entries/$i | sed "s/title .*CentOS/title \"${LABEL_PREFIX}_root\" CentOS/g" > /tmp/${i}_$$ && cp /tmp/${i}_$$ loader/entries/$i
done

cd / && umount /mnt/${LABEL_PREFIX}_boot
