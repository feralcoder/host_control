#!/bin/bash

BACKUP_HOST=dumbledore
BACKUP_DIR=/backups/stack_dumps/

backup_control_make_restore_script () {
  # SRCDIR=/backups/stack_dumps/link_or_dir                       (REQUIRED)
  # DESTVOL=[akgn|bdmb|etc]                                       (REQUIRED)
  # MOUNTS="boot,root,home,var"                                   (REQUIRED)
  # BACKUPSERV=[hostname|local]                                   ("" --> local)
  # OVERWRITE_IDENTITY=true|false                                 ("" --> false)
  # REPARTITION=true|false                                        ("" --> false)
  # REPART_DEVICE=/dev/sdx                                        ("" --> discover from DESTVOL or FAIL)
  local HOST=$1 SRCDIR=$2 DESTVOL=$3 MOUNTS=$4 BACKUPSERV=$5 OVERWRITE_IDENTITY=$6 REPARTITION=$7 REPART_DEVICE=$8
  local SHORT_NAME=`group_logic_get_short_name $HOST`

  [[ $BACKUPSERV == "" ]] && BACKUPSERV=local
  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=false
  [[ $REPARTITION == "" ]] && REPARTITION=false
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



  echo "#!/bin/bash" > $SCRIPT

  # Partition table should be in every backup.  Repartition on restore is optional...
  if [[ "${REPARTITION,,}" != "false" ]] ; then
    [[ $REPART_DEVICE != "" ]] || {
      REPART_DEVICE=`admin_control_find_labeled_drive_by_prefix ${DESTVOL:0:1} $HOST`
      [[ $? == 0 ]] || {
        echo "Could not determine REPART_DEVICE for $HOST"
        return 1
      }
    }
    echo "# REPARTITIONING $REPART_DEVICE" >> $SCRIPT
  fi

  # Mount all the drives we're backing
  for MOUNT in $MOUNTS; do
    echo "mkdir /mnt/${DESTVOL}_${MOUNT} > /dev/null 2>&1" >> $SCRIPT
    echo "mount LABEL=${DESTVOL}_${MOUNT} /mnt/${DESTVOL}_${MOUNT} > /dev/null 2>&1" >> $SCRIPT
    # Clean up after failed mounts...
    echo "rmdir /mnt/${DESTVOL}_${MOUNT} > /dev/null 2>&1" >> $SCRIPT
  done

  local ROOT_EXCLUDE BOOT_EXCLUDE
  if [[ "${OVERWRITE_IDENTITY,,}" != "true" ]]; then
    ROOT_EXCLUDE="--exclude='/etc/fstab*' --exclude='/etc/default/grub*'"
    BOOT_EXCLUDE="--exclude='grub2/grub.cfg*' --exclude='grub2/grubenv*' --exclude='grub2/device.map*'"
  fi


  for MOUNT in $MOUNTS; do
    case $MOUNT in
      boot)
        echo "rsync -avxHAX ${SOURCE_PATH}_boot/  ${DEST_PATH}_boot/ --delete $BOOT_EXCLUDE" >> $SCRIPT
        ;;
      root)
        echo "rsync -avxHAX ${SOURCE_PATH}_root/ ${DEST_PATH}_root/ --delete $ROOT_EXCLUDE" >> $SCRIPT
        ;;
      home)
        echo "rsync -avxHAX ${SOURCE_PATH}_home/ ${DEST_PATH}_home/ --delete" >> $SCRIPT
        ;;
      var)
        echo "rsync -avxHAX ${SOURCE_PATH}_var/ ${DEST_PATH}_var/ --delete" >> $SCRIPT
        ;;
      *)
        ;;
    esac
  done

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

  echo "#!/bin/bash" > $SCRIPT



  # On backup, just dump the partition table every time
  local DEVICE=`admin_control_find_labeled_drive_by_prefix ${SRCVOL:0:1} $HOST`
  [[ $? == 0 ]] || {
    echo "Could not determine REPART_DEVICE for $HOST"
    return 1
  }
  echo "# DUMPING $DEVICE PARTITION TABLE" >> $SCRIPT


  # Mount all the drives we're backing
  for MOUNT in $MOUNTS; do
    echo "mkdir /mnt/${SRCVOL}_${MOUNT} > /dev/null 2>&1" >> $SCRIPT
    echo "mount LABEL=${SRCVOL}_${MOUNT} /mnt/${SRCVOL}_${MOUNT} > /dev/null 2>&1" >> $SCRIPT
    # Clean up after failed mounts...
    echo "rmdir /mnt/${SRCVOL}_${MOUNT} > /dev/null 2>&1" >> $SCRIPT
  done

  # If local backup, create target dir in script.  If remote, create it now from admin server.
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

  for MOUNT in $MOUNTS; do
    case $MOUNT in
      boot)
        echo "rsync -avxHAX ${SOURCE_PATH}_boot/  ${DEST_PATH}/${SHORT_NAME}_boot/ --delete $BOOT_EXCLUDE" >> $SCRIPT
        ;;
      root)
        echo "rsync -avxHAX ${SOURCE_PATH}_root/ ${DEST_PATH}/${SHORT_NAME}_root/ --delete $ROOT_EXCLUDE" >> $SCRIPT
        ;;
      home)
        echo "rsync -avxHAX ${SOURCE_PATH}_home/ ${DEST_PATH}/${SHORT_NAME}_home/ --delete" >> $SCRIPT
        ;;
      var)
        echo "rsync -avxHAX ${SOURCE_PATH}_var/ ${DEST_PATH}/${SHORT_NAME}_var/ --delete" >> $SCRIPT
        ;;
      *)
        ;;
    esac
  done

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
  # REPARTITION=true|false                                         ("" --> false)
  # REPART_DEVICE=/dev/sdx                                         (OPTIONAL, can be discovered by make_script function if target is labeled)
  # NOTE: There is the possibility that OVERWRITE_IDENTITY=false, REPARTITION=true.  Make Sense?  Beware.
  local HOST=$1 SRC=$2 DEST=$3 MOUNTS=$4 BACKUPSERV=$5 OVERWRITE_IDENTITY=$6 REPARTITION=$7 REPART_DEVICE=$8
  [[ $MOUNTS == "" ]] && MOUNTS=boot,root,home,var
  [[ $BACKUPSERV == "" ]] && BACKUPSERV=$BACKUP_HOST
  [[ $OVERWRITE_IDENTITY == "" ]] && OVERWRITE_IDENTITY=false
  [[ $REPARTITION == "" ]] && REPARTITION=false

  local SHORT_NAME=`group_logic_get_short_name $HOST`
  local OLD_RESTORE_LOGS=/tmp/old_restores/$HOST
  [[ -d $OLD_RESTORE_LOGS ]] || mkdir -p $OLD_RESTORE_LOGS
  mv /tmp/restore_output_${SHORT_NAME}_* /tmp/restore_script_${SHORT_NAME}_* $OLD_RESTORE_LOGS >/dev/null 2>&1

  local NOW=`date +%Y%m%d-%H%M%S`

  local SCRIPT=`backup_control_make_restore_script $HOST $SRC $DEST $MOUNTS $BACKUPSERV $OVERWRITE_IDENTITY $REPARTITION "$REPART_DEVICE"`
  ssh_control_sync_as_user root $SCRIPT /root/restore_script_${SHORT_NAME}_${NOW}.sh $HOST
  ssh_control_run_as_user root "chmod 755 /root/restore_script_${SHORT_NAME}_${NOW}.sh" $HOST

  local ERRFILE=restore_output_${SHORT_NAME}_${NOW}_$$_error.log
  local LOGFILE=restore_output_${SHORT_NAME}_${NOW}_$$.log
  ssh_control_run_as_user root "/root/restore_script_${SHORT_NAME}_${NOW}.sh" $HOST > /tmp/$LOGFILE 2> /tmp/$ERRFILE
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

  local SHORT_NAME=`group_logic_get_short_name $HOST`
  local OLD_BACKUP_LOGS=/tmp/old_backups/$HOST
  [[ -d $OLD_BACKUP_LOGS ]] || mkdir -p $OLD_BACKUP_LOGS
  mv /tmp/backup_output_${SHORT_NAME}_* /tmp/backup_script_${SHORT_NAME}_* $OLD_BACKUP_LOGS >/dev/null 2>&1

  local NOW=`date +%Y%m%d-%H%M%S`

  local SCRIPT=`backup_control_make_backup_script $HOST $SRC $DEST $MOUNTS $BACKUPSERV "$BACKUPLINK" $OVERWRITE_IDENTITY`
  ssh_control_sync_as_user root $SCRIPT /root/backup_script_${SHORT_NAME}_${NOW}.sh $HOST
  ssh_control_run_as_user root "chmod 755 /root/backup_script_${SHORT_NAME}_${NOW}.sh" $HOST

  local ERRFILE=backup_output_${SHORT_NAME}_${NOW}_$$_error.log
  local LOGFILE=backup_output_${SHORT_NAME}_${NOW}_$$.log
  ssh_control_run_as_user root "/root/backup_script_${SHORT_NAME}_${NOW}.sh" $HOST > /tmp/$LOGFILE 2> /tmp/$ERRFILE
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
      # ASSUME WE WANT TO RESTORE FROM BACKUPS FROM SAME DRIVESET
      #   Until we build relinker to support agnd, bgnd, gnd --> agnd --> dir...
      RESTORE_DIR=$SRCDIR/${DRIVESET}${SHORT_NAME}_$BACKUPLINK
#      RESTORE_DIR=$SRCDIR/${SHORT_NAME}_$BACKUPLINK
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
      if [[ $BACKUPLINK != "" ]] ; then HOST_BACKUPLINK=${DRIVESET}${SHORT_NAME}_$BACKUPLINK; fi
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

backup_control_sort_backups () {
  local $HOST
  ssh_control_run_as_user root "cd /backups/stack_dumps/ ; mkdir ../keep ../delete; ls -al |grep '^l' | awk '{print "mv " \$11 " ../keep"}' | bash; ls -al |grep '^l' | awk '{print "mv " \$9 " ../keep"}' | bash; mv * ../delete; mv ../keep/* .; rmdir ../keep/" $HOST
}

backup_control_sort_backups_these_hosts () {
  local HOSTS=$1
  local HOST PIDS=""



  local ERROR RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'` 'all_reaped'; do
        if [[ $PID == 'all_reaped' ]]; then
          [[ $ERROR == "" ]] && return 0 || return 1
        else
          wait ${PID} 2>/dev/null
          RETURN_CODE=$?
          if [[ $RETURN_CODE != 0 ]]; then
            echo "Return code for PID $PID: $RETURN_CODE"
            echo "Sort backups, no more info available"
            ERROR=true
          fi
        fi
      done
    else
      backup_control_sort_backups $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Sorting backups on $HOST: $!"
    fi
  done
}
