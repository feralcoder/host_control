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
  [[ $DEBUG == "" ]] || echo IN MAKESCRIPT: HOST:$HOST SRCVOL=$SRCVOL DESTDIR=$DESTDIR MOUNTS=$MOUNTS BACKUPSERV=$BACKUPSERV BACKUPLINK=$BACKUPLINK 1>&2

  local BACKUPSERV_PREFIX
  ( [[ "${BACKUPSERV,,}" == "local" ]] || [[ "$BACKUPSERV" == "" ]] ) && {
    BACKUPSERV_PREFIX=""
  } || {
    BACKUPSERV_PREFIX="$BACKUPSERV:"
  }
  [[ $DEBUG == "" ]] || echo IN MAKESCRIPT: BACKUPSERV=$BACKUPSERV BACKUPSERV_PREFIX=$BACKUPSERV_PREFIX 1>&2

  local NOW=`date +%Y%m%d-%H%M%S`
  MOUNTS=`echo $MOUNTS | sed 's/,/ /g'`

  local SOURCE_PATH=/mnt/$SRCVOL
  local DEST_PATH_ON_TARGET=$DESTDIR/${HOST}_$NOW
  local DEST_PATH=${BACKUPSERV_PREFIX}$DEST_PATH_ON_TARGET

  local SCRIPT=/tmp/backup_script_${HOST}_${NOW}_$$.sh
cat << EOF > $SCRIPT
#!/bin/bash

for MOUNT in $MOUNTS; do
  mkdir /mnt/${SRCVOL}_\${MOUNT} > /dev/null 2>&1
  mount LABEL=${SRCVOL}_\${MOUNT} /mnt/${SRCVOL}_\${MOUNT} > /dev/null 2>&1
  # Clean up after failed mounts...
  rmdir /mnt/${SRCVOL}_\${MOUNT} > /dev/null 2>&1
done

EOF

  if [[ $BACKUPSERV_PREFIX == "" ]] ; then
    echo "mkdir -p $DEST_PATH_ON_TARGET" >> $SCRIPT
  else
    OUTPUT=`ssh_control_run_as_user root "mkdir -p $DEST_PATH_ON_TARGET; chmod 775 $DEST_PATH_ON_TARGET" $BACKUPSERV`
  fi

  local ROOT_EXCLUDE BOOT_EXCLUDE
  if [[ "${OVERWRITE_IDENTITY,,}" != "true" ]]; then
    local ROOT_EXCLUDE="--exclude='/etc/fstab*' --exclude='/etc/default/grub*'"
    local BOOT_EXCLUDE="--exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*'"
  fi

cat << EOF >> $SCRIPT
rsync -avxHAX ${SOURCE_PATH}_root/ ${DEST_PATH}/${HOST}_root/ --delete $ROOT_EXCLUDE
rsync -avxHAX ${SOURCE_PATH}_home/ ${DEST_PATH}/${HOST}_home/ --delete
rsync -avxHAX ${SOURCE_PATH}_var/ ${DEST_PATH}/${HOST}_var/ --delete
rsync -avxHAX ${SOURCE_PATH}_boot/  ${DEST_PATH}/${HOST}_boot/ --delete $BOOT_EXCLUDE
EOF

  if [[ $BACKUPLINK != "" ]]; then
    if [[ $BACKUPSERV_PREFIX == "" ]] ; then
      echo "rm $DESTDIR/$BACKUPLINK" >> $SCRIPT
      echo "ln -s $DEST_PATH $DESTDIR/$BACKUPLINK" >> $SCRIPT
    else
      OUTPUT=`ssh_control_run_as_user root "rm $DESTDIR/$BACKUPLINK; ln -s $DEST_PATH_ON_TARGET $DESTDIR/$BACKUPLINK" $BACKUPSERV`
    fi
  fi

echo $SCRIPT
}



backup_control_restore () {
  # SRC=/backups/undercloud_dumps/dumbledore_02_Ussuri_Undercloud
  # DEST=[admb|bkgn|etc]
  # FINAL_TARGET=[admin|default]
  local HOST=$1 SRC=$2 DEST=$3 FINAL_TARGET=$4

  local NOW=`date +%Y%m%d-%H%M%S`

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
  # SRC=[admb|bkgn|etc]                          (REQUIRED)
  # DEST=/backups/stack_dumps/                   ("" --> /backups/stack_dumps/)
  # MOUNTS=boot,root,home,var                    ("" --> boot,root,home,var)
  # BACKUPSERV=local|hostname                    ("" --> dumbledore)
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud   (OPTIONAL)
  # OVERWRITE_IDENTITY=true|false                ("" --> false)
  local HOST=$1 SRC=$2 DEST=$3 MOUNTS=$4 BACKUPSERV=$5 BACKUPLINK=$6 OVERWRITE_IDENTITY=$7
  [[ $DEST == "" ]] && DEST=/backups/stack_dumps/
  [[ $MOUNTS == "" ]] && MOUNTS=boot,root,home,var
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=dumbledore
  [[ $BACKUPLINK == "" ]] && BACKUPLINK=""
  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=false

  local NOW=`date +%Y%m%d-%H%M%S`

  local SCRIPT=`backup_control_make_backup_script $HOST $SRC $DEST $MOUNTS $BACKUPSERV "$BACKUPLINK" $OVERWRITE_IDENTITY`
  echo $NOW $SCRIPT
  ssh_control_sync_as_user root $SCRIPT /root/backup_script_${HOST}_${NOW}.sh $HOST
  ssh_control_run_as_user root "chmod 755 /root/backup_script_${HOST}_${NOW}.sh" $HOST
  SYNC_OUTPUT=$(ssh_control_run_as_user root "/root/backup_script_${HOST}_${NOW}.sh" $HOST)

  echo "$SYNC_OUTPUT" > /tmp/backup_output_$$.log
  ssh_control_sync_as_user root /tmp/backup_output_$$.log /root/backup_output_$NOW.log $HOST
}


backup_control_backup_all () {
  local BACKUPLINK=$1 DRIVESET=$2 MOUNTS=$3 BACKUPSERV=$4 OVERWRITE_IDENTITY=$5
  # ALL ARGS ARE OPTIONAL:
  # BACKUPLINK="" | ie 02_Ussuri_Undercloud - will be prepended with $HOST unless NULL
  # DRIVESET=a|b|...|x                     ("" --> "a")
  # MOUNTS=boot,root,home,var              (or boot,root,home if driveset=x)
  # BACKUPSERV=hostname|local              ("" --> "dumbledore")
  # OVERWRITE_IDENTITY=true|false          ("" --> true)
  [[ $DRIVESET == "" ]] && DRIVESET=a
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=dumbledore
  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=true
  if [[ $MOUNTS == "" ]] ; then
    if [[ "${DRIVESET,,}" =~ ^(a|b|c|d|e)$ ]]; then
      MOUNTS="boot,root,home,var"
    elif [[ "${DRIVESET,,}" == x ]]; then
      MOUNTS="boot,root,home"
    else
      MOUNTS="boot,root,home,var"
    fi
  fi

  local HOST HOST_BACKUPLINK PIDS RETURN_CODE
  for HOST in mtn lmn bmn kgn neo str mrl gnd yda dmb     now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $?"
        fi
      done
    else
      if [[ $BACKUPLINK != "" ]] ; then HOST_BACKUPLINK=${HOST}_$BACKUPLINK; fi
      if [[ "${HOST,,}" =~ ^(kgn|neo|bmn|lmn|mtn|dmb)$ ]]; then
        echo Starting: backup_control_backup $HOST ${DRIVESET}$HOST /backups/stack_dumps/ $MOUNTS local "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY
        backup_control_backup $HOST ${DRIVESET}$HOST /backups/stack_dumps/ $MOUNTS local "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY &
      elif [[ "${HOST,,}" =~ ^(str|dmb|yda|gnd)$ ]]; then
        echo Starting: backup_control_backup $HOST ${DRIVESET}$HOST /backups/stack_dumps/ $MOUNTS $BACKUPSERV "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY
        backup_control_backup $HOST ${DRIVESET}$HOST /backups/stack_dumps/ $MOUNTS $BACKUPSERV "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY &
      fi
      PIDS="$PIDS:$!"
      echo "Started Backup for $HOST..."
    fi
  done
}
