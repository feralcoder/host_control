#!/bin/bash

. ilo_common.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh

. ssh_control.sh
. os_control.sh




undercloud_control_make_restore_script () {
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

rsync -avxHAX \${SOURCE_PATH}_root/ \${DEST_PATH}_root/ --exclude='/etc/fstab*' --exclude='/etc/default/grub*' --delete
rsync -avxHAX \${SOURCE_PATH}_home/ \${DEST_PATH}_home/ --delete
rsync -avxHAX \${SOURCE_PATH}_var/ \${DEST_PATH}_var/ --delete
rsync -avxHAX \${SOURCE_PATH}_boot/  \${DEST_PATH}_boot/ --exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*' --delete

EOF

echo /tmp/restore_undercloud.sh_$$
}




undercloud_control_make_backup_script () {
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





undercloud_control_restore () {
  # SRC=/backups/undercloud_dumps/dumbledore_02_Ussuri_Undercloud
  # DEST=[admb|bkgn|etc]
  # FINAL_TARGET=[admin|default]
  local HOST=$1 SRC=$2 DEST=$3 FINAL_TARGET=$4

  local NOW=`date +%Y%m%d-%H%M`

  os_control_boot_to_target_installation admin $HOST
  if [[ $? != 0 ]]; then
    echo "Failed to boot $HOST to ADMIN!"
    return 1
  fi

  local SCRIPT=`undercloud_control_make_restore_script $HOST $SRC $DEST`
  ssh_control_sync_as_user root $SCRIPT /root/undercloud_restore_${NOW}.sh dmb
  ssh_control_run_as_user root "chmod 755 /root/undercloud_restore_${NOW}.sh" dmb
  SYNC_OUTPUT=$(ssh_control_run_as_user root "/root/undercloud_restore_${NOW}.sh" dmb)

  echo "$SYNC_OUTPUT" > /tmp/restore_output_$$.log
  ssh_control_sync_as_user root /tmp/restore_output_$$.log /root/restore_output_$NOW.log dmb
 
  if [[ $FINAL_TARGET == "default" ]]; then
    os_control_boot_to_target_installation default $HOST
    if [[ $? != 0 ]]; then
      echo "Failed to boot $HOST to DEFAULT!"
      return 1
    fi
  fi
}



undercloud_control_backup () {
  # SRC=[admb|bkgn|etc]
  # DEST=/backups/undercloud_dumps/
  # FINAL_TARGET=[admin|default]
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  local HOST=$1 SRC=$2 DEST=$3 FINAL_TARGET=$4 BACKUPLINK=$5

  local NOW=`date +%Y%m%d-%H%M`

  os_control_boot_to_target_installation admin $HOST
  if [[ $? != 0 ]]; then
    echo "Failed to boot $HOST to ADMIN!"
    return 1
  fi

  local SCRIPT=`undercloud_control_make_backup_script $HOST $SRC $DEST $BACKUPLINK`
  ssh_control_sync_as_user root $SCRIPT /root/undercloud_backup_${NOW}.sh dmb
  ssh_control_run_as_user root "chmod 755 /root/undercloud_backup_${NOW}.sh" dmb
  SYNC_OUTPUT=$(ssh_control_run_as_user root "/root/undercloud_backup_${NOW}.sh" dmb)

  echo "$SYNC_OUTPUT" > /tmp/backup_output_$$.log
  ssh_control_sync_as_user root /tmp/backup_output_$$.log /root/backup_output_$NOW.log dmb


  if [[ $FINAL_TARGET == "default" ]]; then
    os_control_boot_to_target_installation default $HOST
    if [[ $? != 0 ]]; then
      echo "Failed to boot $HOST to DEFAULT!"
      return 1
    fi
  fi
}



undercloud_control_backup_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  undercloud_control_backup dmb bdmb /backups/undercloud_dumps default $BACKUPLINK
}

undercloud_control_restore_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  undercloud_control_restore dmb /backups/undercloud_dumps/$BACKUPLINK bdmb
}

undercloud_control_build_the_whole_fucking_thing () {
  local HOST=$1

  undercloud_control_restore dmb admb /backups/undercloud_dumps/dumbledore_01_CentOS_8 default
  ssh_control_run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_undercloud.sh" dmb
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_undercloud.sh" dmb)
  # [[ $OUTPUT == "UNDERCLOUD OK" ]] || { echo "Undercloud installation incomplete, check it out!"; return 1; }
  undercloud_control_backup dmb admb /backups/undercloud_dumps default new-dumbledore_02_Ussuri_Undercloud
  ssh_control_run_as_user root "DEFOPTS=true ~cliff/CODE/feralcoder/train8/setup_overcloud.sh" dmb
  # OUTPUT=$(run_as_user root "~cliff/CODE/feralcoder/train8/verify_overcloud.sh" dmb)
  # [[ $OUTPUT == "OVERCLOUD OK" ]] || { echo "Overcloud installation incomplete, check it out!"; return 1; }
  undercloud_control_backup dmb admb /backups/undercloud_dumps default new-dumbledore_03_Ussuri_Overcloud
}
