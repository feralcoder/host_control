#!/bin/bash

BACKUP_HOST=dumbledore
BACKUP_DIR=/backups/stack_dumps/

backup_control_make_restore_script () {
  # SRCDIR=/backups/stack_dumps/link_or_dir                       (REQUIRED)
  # DESTVOL=[akgn|bdmb|etc]                                       (REQUIRED)
  # MOUNTS="boot,root,home,var"                                   (REQUIRED)
  # BACKUPSERV=[hostname|local]                                   ("" --> local)
  # OVERWRITE_IDENTITY=true|false                                 ("" --> false)
  local HOST=$1 SRCDIR=$2 DESTVOL=$3 MOUNTS=$4 BACKUPSERV=$5 OVERWRITE_IDENTITY=$6
  local SHORT_NAME=`group_logic_get_short_name $HOST`

  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=false
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=local
  local BACKUPSERV_PREFIX
  [[ "${BACKUPSERV,,}" == "local" ]] && {
    BACKUPSERV_PREFIX=""
  } || {
    BACKUPSERV_PREFIX="$BACKUPSERV:"
  }

  local NOW=`date +%Y%m%d-%H%M%S`
  MOUNTS=`echo $MOUNTS | sed 's/,/ /g'`

  local ROOT_EXCLUDE BOOT_EXCLUDE
  if [[ "${OVERWRITE_IDENTITY,,}" != "true" ]]; then
    local ROOT_EXCLUDE="--exclude='/etc/fstab*' --exclude='/etc/default/grub*'"
    local BOOT_EXCLUDE="--exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*'"
  fi

  local SOURCE_PATH=${BACKUPSERV_PREFIX}$SRCDIR/${SHORT_NAME}
  local DEST_PATH=/mnt/$DESTVOL

  local SCRIPT=/tmp/restore_script_${SHORT_NAME}_${NOW}_$$.sh



cat << EOF > $SCRIPT
#!/bin/bash

for MOUNT in $MOUNTS; do
  mkdir /mnt/${DESTVOL}_\${MOUNT} > /dev/null 2>&1
  mount LABEL=${DESTVOL}_\${MOUNT} /mnt/${DESTVOL}_\${MOUNT} > /dev/null 2>&1
  # Clean up after failed mounts...
  rmdir /mnt/${DESTVOL}_\${MOUNT} > /dev/null 2>&1
done
EOF

  local ROOT_EXCLUDE BOOT_EXCLUDE
  if [[ "${OVERWRITE_IDENTITY,,}" != "true" ]]; then
    ROOT_EXCLUDE="--exclude='/etc/fstab*' --exclude='/etc/default/grub*'"
    BOOT_EXCLUDE="--exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*'"
  fi



cat << EOF >> $SCRIPT
rsync -avxHAX ${SOURCE_PATH}_root/ ${DEST_PATH}_root/ --delete $ROOT_EXCLUDE
rsync -avxHAX ${SOURCE_PATH}_home/ ${DEST_PATH}_home/ --delete
rsync -avxHAX ${SOURCE_PATH}_var/ ${DEST_PATH}_var/ --delete
rsync -avxHAX ${SOURCE_PATH}_boot/  ${DEST_PATH}_boot/ --delete $BOOT_EXCLUDE
EOF

echo $SCRIPT
}


backup_control_make_backup_script () {
  # SRCVOL=[akgn|bdmb|etc]                        (REQUIRED)
  # DESTDIR=/backups/stack_dumps/                 (REQUIRED)
  # MOUNTS="boot,root,home,var"                   (REQUIRED)
  # BACKUPSERV=[hostname|local]                   ("" --> local)
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud    (OPTIONAL)
  # OVERWRITE_IDENTITY=true|false                 ("" --> true)
  local HOST=$1 SRCVOL=$2 DESTDIR=$3 MOUNTS=$4 BACKUPSERV=$5 BACKUPLINK=$6 OVERWRITE_IDENTITY=$7
  local SHORT_NAME=`group_logic_get_short_name $HOST`
  [[ $DEBUG == "" ]] || echo IN MAKESCRIPT: HOST:$HOST SRCVOL=$SRCVOL DESTDIR=$DESTDIR MOUNTS=$MOUNTS BACKUPSERV=$BACKUPSERV BACKUPLINK=$BACKUPLINK 1>&2

  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=true
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=local
  local BACKUPSERV_PREFIX
  [[ "${BACKUPSERV,,}" == "local" ]] && {
    BACKUPSERV_PREFIX=""
  } || {
    BACKUPSERV_PREFIX="$BACKUPSERV:"
  }
  [[ $DEBUG == "" ]] || echo IN MAKESCRIPT: BACKUPSERV=$BACKUPSERV BACKUPSERV_PREFIX=$BACKUPSERV_PREFIX 1>&2

  local NOW=`date +%Y%m%d-%H%M%S`
  MOUNTS=`echo $MOUNTS | sed 's/,/ /g'`

  local SOURCE_PATH=/mnt/$SRCVOL
  local DEST_PATH_ON_TARGET=$DESTDIR/${SHORT_NAME}_$NOW
  local DEST_PATH=${BACKUPSERV_PREFIX}$DEST_PATH_ON_TARGET

  local SCRIPT=/tmp/backup_script_${SHORT_NAME}_${NOW}_$$.sh
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
    ROOT_EXCLUDE="--exclude='/etc/fstab*' --exclude='/etc/default/grub*'"
    BOOT_EXCLUDE="--exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*'"
  fi

cat << EOF >> $SCRIPT
rsync -avxHAX ${SOURCE_PATH}_root/ ${DEST_PATH}/${SHORT_NAME}_root/ --delete $ROOT_EXCLUDE
rsync -avxHAX ${SOURCE_PATH}_home/ ${DEST_PATH}/${SHORT_NAME}_home/ --delete
rsync -avxHAX ${SOURCE_PATH}_var/ ${DEST_PATH}/${SHORT_NAME}_var/ --delete
rsync -avxHAX ${SOURCE_PATH}_boot/  ${DEST_PATH}/${SHORT_NAME}_boot/ --delete $BOOT_EXCLUDE
EOF

  if [[ $BACKUPLINK != "" ]]; then
    if [[ $BACKUPSERV_PREFIX == "" ]] ; then
      echo "rm $DESTDIR/$BACKUPLINK" >> $SCRIPT
      echo "ln -s $DEST_PATH $DESTDIR/$BACKUPLINK" >> $SCRIPT
    else
      echo "ssh root@$BACKUPSERV 'rm $DESTDIR/$BACKUPLINK; ln -s $DEST_PATH_ON_TARGET $DESTDIR/$BACKUPLINK'" >> $SCRIPT
      #OUTPUT=`ssh_control_run_as_user root "rm $DESTDIR/$BACKUPLINK; ln -s $DEST_PATH_ON_TARGET $DESTDIR/$BACKUPLINK" $BACKUPSERV`
    fi
  fi

echo $SCRIPT
}


backup_control_restore () {
  # SRC=/backups/stack_dumps/dir_or_link                           (REQUIRED)
  # DEST=[admb|bkgn|etc]                                           (REQUIRED)
  # MOUNTS=boot,root,home,var                                      ("" --> boot,root,home,var)
  # BACKUPSERV=local|hostname                                      ("" --> $BACKUP_HOST)
  # OVERWRITE_IDENTITY=true|false                                  ("" --> false)
  local HOST=$1 SRC=$2 DEST=$3 MOUNTS=$4 BACKUPSERV=$5 OVERWRITE_IDENTITY=$6
  [[ $MOUNTS == "" ]] && MOUNTS=boot,root,home,var
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=$BACKUP_HOST
  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=false

  local NOW=`date +%Y%m%d-%H%M%S`

  local SCRIPT=`backup_control_make_restore_script $HOST $SRC $DEST $MOUNTS $BACKUPSERV $OVERWRITE_IDENTITY`
  ssh_control_sync_as_user root $SCRIPT /root/restore_script_${SHORT_NAME}_${NOW}.sh $HOST
  ssh_control_run_as_user root "chmod 755 /root/restore_script_${SHORT_NAME}_${NOW}.sh" $HOST

  local ERRFILE=restore_output_${SHORT_NAME}_${NOW}_$$_error.log
  local LOGFILE=restore_output_${SHORT_NAME}_${NOW}_$$.log
  ssh_control_run_as_user root "/root/restore_script_${SHORT_NAME}_${NOW}.sh" $HOST > $LOGFILE 2> $ERRFILE
  [[ $? == 0 ]] || echo "Restore had errors!  See logfile $HOST:/root/$ERRFILE"

  ssh_control_sync_as_user root /tmp/$ERRFILE /root/$ERRFILE $HOST
  ssh_control_sync_as_user root /tmp/$LOGFILE /root/$LOGFILE $HOST
}


backup_control_backup () {
  # SRC=[admb|bkgn|etc]                          (REQUIRED)
  # DEST=/backups/stack_dumps/                   ("" --> $BACKUP_DIR)
  # MOUNTS=boot,root,home,var                    ("" --> boot,root,home,var)
  # BACKUPSERV=local|hostname                    ("" --> $BACKUP_HOST)
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud   (OPTIONAL)
  # OVERWRITE_IDENTITY=true|false                ("" --> false)
  local HOST=$1 SRC=$2 DEST=$3 MOUNTS=$4 BACKUPSERV=$5 BACKUPLINK=$6 OVERWRITE_IDENTITY=$7
  [[ $DEST == "" ]] && DEST=$BACKUP_DIR
  [[ $MOUNTS == "" ]] && MOUNTS=boot,root,home,var
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=$BACKUP_HOST
  [[ $BACKUPLINK == "" ]] && BACKUPLINK=""
  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=false

  local NOW=`date +%Y%m%d-%H%M%S`

  local SCRIPT=`backup_control_make_backup_script $HOST $SRC $DEST $MOUNTS $BACKUPSERV "$BACKUPLINK" $OVERWRITE_IDENTITY`
  ssh_control_sync_as_user root $SCRIPT /root/backup_script_${SHORT_NAME}_${NOW}.sh $HOST
  ssh_control_run_as_user root "chmod 755 /root/backup_script_${SHORT_NAME}_${NOW}.sh" $HOST

  local ERRFILE=backup_output_${SHORT_NAME}_${NOW}_$$_error.log
  local LOGFILE=backup_output_${SHORT_NAME}_${NOW}_$$.log
  ssh_control_run_as_user root "/root/backup_script_${SHORT_NAME}_${NOW}.sh" $HOST > $LOGFILE 2> $ERRFILE
  [[ $? == 0 ]] || echo "Backup had errors!  See logfile $HOST:/root/$ERRFILE"

  ssh_control_sync_as_user root /tmp/$ERRFILE /root/$ERRFILE $HOST
  ssh_control_sync_as_user root /tmp/$LOGFILE /root/$LOGFILE $HOST
}



backup_control_restore_all () {
  local BACKUPLINK=$1 SRCDIR=$2 DRIVESET=$3 MOUNTS=$4 BACKUPSERV=$5 OVERWRITE_IDENTITY=$6
  # BACKUPLINK=dumbledore_02_Ussuri_Undercloud - will be prepended with $HOST                         (REQUIRED)
  # SRCDIR=/backups/stack_dumps/                                       ("" --> $BACKUP_DIR)
  # DRIVESET=a|b|...|x                                                 ("" --> "a")
  # MOUNTS=boot,root,home,var                                          (or boot,root,home if driveset=x)
  # BACKUPSERV=hostname|local                                          ("" --> "$BACKUP_HOST")
  # OVERWRITE_IDENTITY=true|false                                      ("" --> false)
  [[ $SRCDIR == "" ]] && SRCDIR=$BACKUP_DIR
  [[ $DRIVESET == "" ]] && DRIVESET=a
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=$BACKUP_HOST
  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=false
  if [[ $MOUNTS == "" ]] ; then
    if [[ "${DRIVESET,,}" =~ ^(a|b|c|d|e)$ ]]; then
      MOUNTS="boot,root,home,var"
    elif [[ "${DRIVESET,,}" == x ]]; then
      MOUNTS="boot,root,home"
    else
      MOUNTS="boot,root,home,var"
    fi
  fi

  local HOST HOST_BACKUPLINK PIDS RETURN_CODE SHORT_NAME RESTORE_DIR
  for HOST in $ALL_HOSTS     now_wait; do
    SHORT_NAME=`group_logic_get_short_name $HOST`
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Restore all: BACKUPLINK:$BACKUPLINK SRCDIR:$SRCDIR DRIVESET:$DRIVESET MOUNTS:$MOUNTS BACKUPSERV:$BACKUPSERV OVERWRITE_IDENTITY:$OVERWRITE_IDENTITY"
        fi
      done
    else
      RESTORE_DIR=$SRCDIR/${SHORT_NAME}_$BACKUPLINK
      if [[ "${SHORT_NAME,,}" =~ ^(kgn|neo|bmn|lmn|mtn|dmb)$ ]]; then
        echo Starting: backup_control_restore $HOST $RESTORE_DIR ${DRIVESET}$SHORT_NAME $MOUNTS local $OVERWRITE_IDENTITY
        backup_control_restore $HOST $RESTORE_DIR ${DRIVESET}$SHORT_NAME $MOUNTS local $OVERWRITE_IDENTITY &
      elif [[ "${SHORT_NAME,,}" =~ ^(str|mrl|yda|gnd)$ ]]; then
        echo Starting: backup_control_restore $HOST $RESTORE_DIR ${DRIVESET}$SHORT_NAME $MOUNTS $BACKUPSERV $OVERWRITE_IDENTITY
        backup_control_restore $HOST $RESTORE_DIR ${DRIVESET}$SHORT_NAME $MOUNTS $BACKUPSERV $OVERWRITE_IDENTITY &
      fi
      PIDS="$PIDS:$!"
      echo "Started Restore for $HOST..."
    fi
  done
}


backup_control_backup_all () {
  local BACKUPLINK=$1 DRIVESET=$2 MOUNTS=$3 BACKUPSERV=$4 OVERWRITE_IDENTITY=$5
  # ALL ARGS ARE OPTIONAL:
  # BACKUPLINK="" | ie 02_Ussuri_Undercloud - will be prepended with $HOST unless NULL
  # DRIVESET=a|b|...|x                     ("" --> "a")
  # MOUNTS=boot,root,home,var              (or boot,root,home if driveset=x)
  # BACKUPSERV=hostname|local              ("" --> "$BACKUP_HOST")
  # OVERWRITE_IDENTITY=true|false          ("" --> true)
  [[ $DRIVESET == "" ]] && DRIVESET=a
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=$BACKUP_HOST
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

  local HOST HOST_BACKUPLINK PIDS RETURN_CODE SHORT_NAME
  for HOST in $ALL_HOSTS     now_wait; do
    SHORT_NAME=`group_logic_get_short_name $HOST`
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Backup all: BACKUPLINK:$BACKUPLINK DRIVESET:$DRIVESET MOUNTS:$MOUNTS BACKUPSERV:$BACKUPSERV OVERWRITE_IDENTITY:$OVERWRITE_IDENTITY"
        fi
      done
    else
      if [[ $BACKUPLINK != "" ]] ; then HOST_BACKUPLINK=${SHORT_NAME}_$BACKUPLINK; fi
      if [[ "${SHORT_NAME,,}" =~ ^(kgn|neo|bmn|lmn|mtn|dmb)$ ]]; then
        echo Starting: backup_control_backup $HOST ${DRIVESET}$SHORT_NAME $BACKUP_DIR $MOUNTS local "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY
        backup_control_backup $HOST ${DRIVESET}$SHORT_NAME $BACKUP_DIR $MOUNTS local "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY &
      elif [[ "${SHORT_NAME,,}" =~ ^(str|mrl|yda|gnd)$ ]]; then
        echo Starting: backup_control_backup $HOST ${DRIVESET}$SHORT_NAME $BACKUP_DIR $MOUNTS $BACKUPSERV "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY
        backup_control_backup $HOST ${DRIVESET}$SHORT_NAME $BACKUP_DIR $MOUNTS $BACKUPSERV "$HOST_BACKUPLINK" $OVERWRITE_IDENTITY &
      fi
      PIDS="$PIDS:$!"
      echo "Started Backup for $HOST..."
    fi
  done
}
