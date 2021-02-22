#!/bin/bash

BACKUP_HOST=dumbledore
BACKUP_DIR=/backups/cloud_backups/

backup_control_make_restore_script () {
  # SRCDIR=/backups/stack_dumps/dumbledore_02_Ussuri_Undercloud
  # DESTVOL=[akgn|bdmb|etc]
  # MOUNTS="boot,root,home,var"
  # BACKUPSERV=[hostname|local]
  local HOST=$1 SRCDIR=$2 DESTVOL=$3 MOUNTS=$4 BACKUPSERV=$5

  local BACKUPSERV_PREFIX
  ( [[ "${BACKUPSERV,,}" == "local" ]] || [[ "$BACKUPSERV" == "" ]] ) && {
    BACKUPSERV_PREFIX=""
  } || {
    BACKUPSERV_PREFIX="$BACKUPSERV:"
  }

  MOUNTS=`echo $MOUNTS | sed 's/,/ /g'`

cat << EOF > /tmp/restore_script.sh_$$
#!/bin/bash

for MOUNT in $MOUNTS; do
  mkdir /mnt/${DESTVOL}_\${MOUNT}
  mount LABEL=${DESTVOL}_\${MOUNT} /mnt/${DESTVOL}_\${MOUNT}
  # Clean up after failed mounts...
  rmdir /mnt/${DESTVOL}_\${MOUNT}
done

SOURCE_PATH=$SRCDIR/${HOST}
DEST_PATH=/mnt/$DESTVOL

rsync -avxHAX ${BACKUPSERV_PREFIX}\${SOURCE_PATH}_root/ \${DEST_PATH}_root/ --exclude='/etc/fstab*' --exclude='/etc/default/grub*' --delete
rsync -avxHAX ${BACKUPSERV_PREFIX}\${SOURCE_PATH}_home/ \${DEST_PATH}_home/ --delete
rsync -avxHAX ${BACKUPSERV_PREFIX}\${SOURCE_PATH}_var/ \${DEST_PATH}_var/ --delete
rsync -avxHAX ${BACKUPSERV_PREFIX}\${SOURCE_PATH}_boot/  \${DEST_PATH}_boot/ --exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*' --delete

EOF

echo /tmp/restore_script.sh_$$
}



backup_control_make_backup_script () {
  # SRCVOL=[akgn|bdmb|etc]
  # DESTDIR=/backups/stack_dumps/
  # MOUNTS="boot,root,home,var"
  # BACKUPSERV=[hostname|local]
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  local HOST=$1 SRCVOL=$2 DESTDIR=$3 MOUNTS=$4 BACKUPSERV=$5 BACKUPLINK=$6

  local BACKUPSERV_PREFIX
  ( [[ "${BACKUPSERV,,}" == "local" ]] || [[ "$BACKUPSERV" == "" ]] ) && {
    BACKUPSERV_PREFIX=""
  } || {
    BACKUPSERV_PREFIX="$BACKUPSERV:"
  }

  local NOW=`date +%Y%m%d-%H%M`
  MOUNTS=`echo $MOUNTS | sed 's/,/ /g'`

cat << EOF > /tmp/backup_script.sh_$$
#!/bin/bash

for MOUNT in $MOUNTS; do
  mkdir /mnt/${SRCVOL}_\${MOUNT}
  mount LABEL=${SRCVOL}_\${MOUNT} /mnt/${SRCVOL}_\${MOUNT}
  # Clean up after failed mounts...
  rmdir /mnt/${SRCVOL}_\${MOUNT}
done

SOURCE_PATH=/mnt/$SRCVOL
DEST_PATH=${BACKUPSERV_PREFIX}$DESTDIR/${HOST}_$NOW
EOF

  if [[ $BACKUPSERV_PREFIX == "" ]] ; then
    echo "mkdir \$DEST_PATH" >> /tmp/backup_script.sh_$$
  else
    OUTPUT=`ssh_control_run_as_user root "mkdir $DEST_PATH; chmod 775 $DEST_PATH" $BACKUPSERV`
  fi


cat << EOF >> /tmp/backup_script.sh_$$
rsync -avxHAX \${SOURCE_PATH}_root/ \${DEST_PATH}/${HOST}_root/ --exclude='/etc/fstab*' --exclude='/etc/default/grub*' --delete
rsync -avxHAX \${SOURCE_PATH}_home/ \${DEST_PATH}/${HOST}_home/ --delete
rsync -avxHAX \${SOURCE_PATH}_var/ \${DEST_PATH}/${HOST}_var/ --delete
rsync -avxHAX \${SOURCE_PATH}_boot/  \${DEST_PATH}/${HOST}_boot/ --exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*' --delete

EOF

  if [[ $BACKUPSERV_PREFIX == "" ]] ; then
    echo "mkdir \$DEST_PATH" >> /tmp/backup_script.sh_$$
  else
    OUTPUT=`ssh_control_run_as_user root "mkdir $DESTDIR/${HOST}_$NOW; chmod 775 $DEST_PATH" $BACKUPSERV`
  fi

  if [[ $BACKUPLINK != "" ]]; then
    if [[ $BACKUPSERV_PREFIX == "" ]] ; then
      echo "rm $DESTDIR/$BACKUPLINK"
      echo "ln -s \$DEST_PATH $DESTDIR/$BACKUPLINK"
    else
      OUTPUT=`ssh_control_run_as_user root "rm $DESTDIR/$BACKUPLINK; ln -s $DESTDIR/${HOST}_$NOW $DESTDIR/$BACKUPLINK" $BACKUPSERV`
    fi
  fi

echo /tmp/backup_script.sh_$$
}



backup_control_restore () {
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

  local SCRIPT=`backup_control_make_restore_script $HOST $SRC $DEST boot,root,home,var local`
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



backup_control_backup () {
  # SRC=[admb|bkgn|etc]
  # DEST=/backups/stack_dumps/
  # FINAL_TARGET=[admin|default]
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  local HOST=$1 SRC=$2 DEST=$3 BACKUPLINK=$5

  local NOW=`date +%Y%m%d-%H%M`

  local SCRIPT=`backup_control_make_backup_script $HOST $SRC $DEST boot,root,home,var dumbledore $BACKUPLINK`
  echo $NOW $SCRIPT
  ssh_control_sync_as_user root $SCRIPT /root/backup_script_${NOW}.sh $HOST
  ssh_control_run_as_user root "chmod 755 /root/backup_script_${NOW}.sh" $HOST
  SYNC_OUTPUT=$(ssh_control_run_as_user root "/root/backup_script_${NOW}.sh" $HOST)

  echo "$SYNC_OUTPUT" > /tmp/backup_output_$$.log
  ssh_control_sync_as_user root /tmp/backup_output_$$.log /root/backup_output_$NOW.log $HOST
}



backup_control_backup_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  backup_control_backup dmb bdmb /backups/undercloud_dumps default $BACKUPLINK
}

backup_control_restore_dumbledore () {
  local BACKUPLINK=$1
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud
  backup_control_restore dmb /backups/undercloud_dumps/$BACKUPLINK bdmb
}

