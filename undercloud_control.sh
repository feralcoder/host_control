#!/bin/bash

. ilo_control.sh
. ssh_control.sh
. os_control.sh




make_undercloud_restore_script () {
  # SRC=/backups/undercloud_dumps/dumbledore_02_Ussuri_Undercloud
  # DEST=[akgn|bdmb|etc]
  local HOST=$1 SRC=$2 DEST=$3

cat << EOF > /tmp/restore_undercloud.sh_$$
#!/bin/bash

for mount in boot root home var; do
  mkdir /mnt/${DEST}_\${mount}
  mount LABEL=${DEST}_\${mount} /mnt/${DEST}_\${mount}
  rmdir /mnt/${DEST}_\${mount}
done

SOURCE_PATH=$SRC/${HOST}
DEST_PATH=/mnt/$DEST

rsync -avxHAX \${SOURCE_PATH}/${HOST}_root/ \${DEST_PATH}_root/ --exclude='/etc/fstab*' --exclude='/etc/default/grub*' --delete
rsync -avxHAX \${SOURCE_PATH}/${HOST}_home/ \${DEST_PATH}_home/ --delete
rsync -avxHAX \${SOURCE_PATH}/${HOST}_var/ \${DEST_PATH}_var/ --delete
rsync -avxHAX \${SOURCE_PATH}/${HOST}_boot/  \${DEST_PATH}_boot/ --exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*' --delete

EOF

echo /tmp/restore_undercloud.sh_$$
}




make_undercloud_backup_script () {
  # SRC=[admb|bkgn|etc]
  # DEST=/backups/undercloud_dumps/
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  local HOST=$1 SRC=$2 DEST=$3 BACKUPLINK=$4

cat << EOF > /tmp/backup_undercloud.sh_$$
#!/bin/bash

for mount in boot root home var; do
  mkdir /mnt/${SRC}_\${mount}
  mount LABEL=${SRC}_\${mount} /mnt/${SRC}_\${mount}
  rmdir /mnt/${SRC}_\${mount}
done

SOURCE_PATH=/mnt/$SRC
DEST_PATH=$DEST/${HOST}_$NOW

mkdir \$DEST_PATH
rsync -avxHAX \${SOURCE_PATH}_root/ \${DEST_PATH}/${HOST}_root/ --exclude='/etc/fstab*' --exclude='/etc/default/grub*' --delete
rsync -avxHAX \${SOURCE_PATH}_home/ \${DEST_PATH}/${HOST}_home/ --delete
rsync -avxHAX \${SOURCE_PATH}_var/ \${DEST_PATH}/${HOST}_var/ --delete
rsync -avxHAX \${SOURCE_PATH}_boot/  \${DEST_PATH}/${HOST}_boot/ --exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*' --delete

EOF

if [[ $BACKUPLINK != "" ]]; then
cat << EOF >> /tmp/backup_undercloud.sh_$$
rm $DEST/$BACKUPLINK
ln -s \$DEST_PATH $DEST/$BACKUPLINK
EOF
fi

echo /tmp/backup_undercloud.sh_$$
}





restore_undercloud () {
  # SRC=/backups/undercloud_dumps/dumbledore_02_Ussuri_Undercloud
  # DEST=[admb|bkgn|etc]
  # FINAL_TARGET=[admin|default]
  local HOST=$1 SRC=$2 DEST=$3 FINAL_TARGET=$4
  local IP=`getent hosts $HOST | awk '{print $1}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  local NOW=`date +%Y%m%d-%H%M`

  boot_to_target_installation $HOST "admin"
  if [[ $? != 0 ]]; then
    echo "Failed to boot $HOST to ADMIN!"
    return 1
  fi

  local SCRIPT=`make_undercloud_restore_script $HOST $SRC $DEST`
  sync_as_user root $SCRIPT /root/undercloud_restore_${NOW}.sh dmb $IP
  run_as_user root "chmod 755 /root/undercloud_restore_${NOW}.sh" dmb $IP
  SYNC_OUTPUT=$(run_as_user root "/root/undercloud_restore_${NOW}.sh" dmb $IP)

  echo "$SYNC_OUTPUT" > /tmp/restore_output_$$.log
  sync_as_user root /tmp/restore_output_$$.log /root/restore_output_$NOW.log dmb $IP
 
  if [[ $FINAL_TARGET == "default" ]]; then
    boot_to_target_installation $HOST "default"
    if [[ $? != 0 ]]; then
      echo "Failed to boot $HOST to DEFAULT!"
      return 1
    fi
  fi
}



backup_undercloud () {
  # SRC=[admb|bkgn|etc]
  # DEST=/backups/undercloud_dumps/
  # FINAL_TARGET=[admin|default]
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  local HOST=$1 SRC=$2 DEST=$3 FINAL_TARGET=$4 BACKUPLINK=$5
  local IP=`getent hosts $HOST | awk '{print $1}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  local NOW=`date +%Y%m%d-%H%M`

  boot_to_target_installation $HOST "admin"
  if [[ $? != 0 ]]; then
    echo "Failed to boot $HOST to ADMIN!"
    return 1
  fi

  local SCRIPT=`make_undercloud_backup_script $HOST $SRC $DEST $BACKUPLINK`
  sync_as_user root $SCRIPT /root/undercloud_backup_${NOW}.sh dmb $IP
  run_as_user root "chmod 755 /root/undercloud_backup_${NOW}.sh" dmb $IP
  SYNC_OUTPUT=$(run_as_user root "/root/undercloud_backup_${NOW}.sh" dmb $IP)

  echo "$SYNC_OUTPUT" > /tmp/backup_output_$$.log
  sync_as_user root /tmp/backup_output_$$.log /root/backup_output_$NOW.log dmb $IP


  if [[ $FINAL_TARGET == "default" ]]; then
    boot_to_target_installation $HOST "default"
    if [[ $? != 0 ]]; then
      echo "Failed to boot $HOST to DEFAULT!"
      return 1
    fi
  fi
}



backup_undercloud_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  backup_undercloud dmb admb /backups/undercloud_dumps default $BACKUPLINK
}

restore_undercloud_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  restore_undercloud dmb /backups/undercloud_dumps/$BACKUPLINK admb default
}

build_the_whole_fucking_thing () {
  local HOST=$1
  local IP=`getent hosts $HOST | awk '{print $1}'`
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  restore_undercloud dmb admb /backups/undercloud_dumps/dumbledore_01_CentOS_8 default
  run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_undercloud.sh" dmb $IP
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_undercloud.sh" dmb $IP)
  # [[ $OUTPUT == "UNDERCLOUD OK" ]] || { echo "Undercloud installation incomplete, check it out!"; return 1; }
  backup_undercloud dmb admb /backups/undercloud_dumps default new-dumbledore_02_Ussuri_Undercloud
  run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_overcloud.sh" dmb $IP
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_overcloud.sh" dmb $IP)
  # [[ $OUTPUT == "OVERCLOUD OK" ]] || { echo "Overcloud installation incomplete, check it out!"; return 1; }
  backup_undercloud dmb admb /backups/undercloud_dumps default new-dumbledore_03_Ussuri_Overcloud
}


$@
