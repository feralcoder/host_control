#!/bin/bash


admin_control_get_sudo_password () {
  local PASSWORD

  # if ~/.password exists and works, use it
  [[ -f ~/.password ]] && {
    cat ~/.password | sudo -k -S ls >/dev/null 2>&1
    if [[ $? == 0 ]] ; then
      echo ~/.password
      return
    fi
  }

  # either ~.password doesn't exiist, or it doesn't work
  read -s -p "Enter Sudo Password: " PASSWORD
  touch /tmp/password_$$
  chmod 600 /tmp/password_$$
  echo $PASSWORD > /tmp/password_$$
  echo /tmp/password_$$
}

admin_control_mount_xax () {
  local HOST=$1
  ssh_control_run_as_user root "for mount in boot root home; \
                                 do mkdir /mnt/xax_\${mount}; \
                                 mount LABEL=xax_\${mount} /mnt/xax_\${mount}; \
                                 rmdir /mnt/xax_\${mount}; done;" $HOST
}

admin_control_mount_everything () {
  local HOST=$1
  local SHORT_NAME=`group_logic_get_short_name $HOST`
  ssh_control_run_as_user root "HOST_ABBREV=$SHORT_NAME; for i in a b c x 8; do for mount in boot root home var; \
                                 do mkdir /mnt/\${i}\${HOST_ABBREV}_\${mount}; \
                                 mount LABEL=\${i}\${HOST_ABBREV}_\${mount} /mnt/\${i}\${HOST_ABBREV}_\${mount}; \
                                 rmdir /mnt/\${i}\${HOST_ABBREV}_\${mount}; done; done;" $HOST
}

admin_control_mount_everything_these_hosts () {
  local HOSTS=$1

  local SHORT_NAME HOST RETURN_CODE PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Mount everything, no more info available"
        fi
      done
    else
      admin_control_mount_everything $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Mounting all volumes on $HOST..."
    fi
  done
}

admin_control_sync_keys_from_xax () {
  local HOST=$1

  local SHORT_NAME=`group_logic_get_short_name $HOST`
  admin_control_mount_xax $HOST
  ssh_control_run_as_user root "HOST_ABBREV=$SHORT_NAME; rsync -avH /mnt/xax_home/cliff/.ssh/ ~cliff/.ssh/; \
                                rsync -avH /mnt/xax_root/root/.ssh/ ~/.ssh/; \
                                rsync -avH /mnt/xax_root/etc/ssh/ssh_host_* /etc/ssh/" $HOST
}
admin_control_sync_keys_from_admin () {
  local HOST=$1

  local SHORT_NAME=`group_logic_get_short_name $HOST`
  admin_control_mount_everything $HOST
  ssh_control_run_as_user root "HOST_ABBREV=$SHORT_NAME; rsync -avH /mnt/x\${HOST_ABBREV}_home/cliff/.ssh/ ~cliff/.ssh/; \
                                rsync -avH /mnt/x\${HOST_ABBREV}_root/root/.ssh/ ~/.ssh/; \
                                rsync -avH /mnt/x\${HOST_ABBREV}_root/etc/ssh/ssh_host_* /etc/ssh/" $HOST
}

admin_control_sync_keys_from_admin_these_hosts () {
  local HOSTS=$1

  local HOST RETURN_CODE SHORT_NAME PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Sync keys from admin, no more info available"
        fi
      done
    else
      admin_control_sync_keys_from_admin $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Syncing keys on $HOST..."
    fi
  done
}



admin_control_sync_keys_to_admin () {
  local HOST=$1

  local SHORT_NAME=`group_logic_get_short_name $HOST`
  admin_control_mount_everything $HOST
  ssh_control_run_as_user root "HOST_ABBREV=$SHORT_NAME; rsync -avH ~cliff/.ssh/ /mnt/x\${HOST_ABBREV}_home/cliff/.ssh/ ; \
                                rsync -avH ~/.ssh/ /mnt/x\${HOST_ABBREV}_root/root/.ssh/ ; \
                                rsync -avH /etc/ssh/ssh_host_* /mnt/x\${HOST_ABBREV}_root/etc/ssh/" $HOST
}


admin_control_sync_keys_to_admin_these_hosts () {
  local HOSTS=$1

  local HOST RETURN_CODE SHORT_NAME PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Sync keys to admin, no more info available"
        fi
      done
    else
      admin_control_sync_keys_to_admin $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Syncing keys on $HOST..."
    fi
  done
}



admin_control_sync_keys_to_xax () {
  local HOST=$1

  admin_control_mount_xax $HOST
  ssh_control_run_as_user root "rsync -avH ~cliff/.ssh/ /mnt/xax_home/cliff/.ssh/ ; \
                                rsync -avH ~/.ssh/ /mnt/xax_root/root/.ssh/ ; \
                                rsync -avH /etc/ssh/ssh_host_* /mnt/xax_root/etc/ssh/" $HOST
}


admin_control_sync_keys_to_xax_these_hosts () {
  local HOSTS=$1

  local HOST RETURN_CODE SHORT_NAME PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Sync keys to xax, no more info available"
        fi
      done
    else
      admin_control_sync_keys_to_admin $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Syncing keys on $HOST..."
    fi
  done
}

admin_control_bootstrap_admin () {
  local HOST=$1

  local PASSFILE=`admin_control_get_sudo_password`
  [[ -f ~/.password ]] || {
    mv $PASSFILE ~/.password
  }

  echo "Installing, configuring git."
  GIT_PASS=`cat ~/.git_password`
  ssh_control_sync_as_user cliff ~/.git_password /home/cliff/.git_password $HOST
  ssh_control_run_as_user cliff "git config --global user.name 'Cliff McIntire'; git config --global user.email 'feralcoder@gmail.com'; GIT_NAME=feralcoder; GIT_PASS=`cat ~/.git_password`; mkdir -p ~/CODE/feralcoder ; cd ~/CODE/feralcoder; git clone https://feralcoder:${GIT_PASS}@github.com/feralcoder/bootstrap-scripts; cd bootstrap-scripts" $HOST
  # In case bootstrap-scripts was already cloned there...
  ssh_control_run_as_user cliff "cd ~/CODE/feralcoder/bootstrap-scripts; sed -i -E 's|(.*feralcoder:)[^@]+(@.*)|\1$GIT_PASS\2|g' .git/config; git pull" $HOST

  ssh_control_sync_as_user cliff ~/.password /home/cliff/.password $HOST
  ssh_control_run_as_user cliff "rm ~/.local_settings; ~/CODE/feralcoder/bootstrap-scripts/admin.sh" $HOST
}

admin_control_make_no_crossboot () {
  local HOST=$1
  ssh_control_run_as_user root "chmod 644 /etc/grub.d/30_os-prober; grub2-mkconfig -o /boot/grub2/grub.cfg.no-crossboot; chmod 755 /etc/grub.d/30_os-prober" $HOST
}

admin_control_fix_grub_os_prober () {
  local HOST=$1
  ssh_control_sync_as_user root $CONTROL_DIR/scripts/30_os-prober /etc/grub.d/ $HOST
  ssh_control_run_as_user root "chmod 755 /etc/grub.d/30_os-prober; chown root:root /etc/grub.d/30_os-prober" $HOST
}

admin_control_fix_grub () {
  local HOST=$1
  local TIMEOUT=$2
  [[ $TIMEOUT != "" ]] || TIMEOUT=30
  admin_control_make_no_crossboot $HOST
  local SHORT_NAME=`group_logic_get_short_name $HOST`
  ssh_control_sync_as_user root $CONTROL_DIR/scripts/fix_grub.sh /root/fix_grub.sh $HOST
  ssh_control_run_as_user root "echo $SHORT_NAME > /root/abbrev_hostname; chmod 755 /root/fix_grub.sh; TIMEOUT=$TIMEOUT /root/fix_grub.sh" $HOST
}

admin_control_clone () {
  local SRC_DEV=$1 DEST_DEV=$2 HOST=$3
  echo CLONING $SRC_DEV to $DEST_DEV on $HOST
  admin_control_umount_all_parts $SRC_DEV $HOST
  admin_control_umount_all_parts $DEST_DEV $HOST
  ssh_control_sync_as_user root  $CONTROL_DIR/scripts/dynamic_clone.sh /root/dynamic_clone.sh $HOST
  ssh_control_run_as_user root "/root/dynamic_clone.sh $SRC_DEV $DEST_DEV" $HOST
}

admin_control_fix_labels () {
  local DEVICE=$1 PREFIX=$2 HOST=$3
  local SHORT_NAME=`group_logic_get_short_name $HOST`
  ssh_control_sync_as_user root  $CONTROL_DIR/scripts/fix_labels.sh /root/fix_labels.sh $HOST
  ssh_control_run_as_user root "/root/fix_labels.sh $DEVICE ${PREFIX}${SHORT_NAME}" $HOST
}

admin_control_fix_admin_key () {
  ###### SECOND ARGEMUNT IS LONG NAME FOR FUCKS SAKE
  local DEVICE=$1 LONG_HOSTNAME=$2
  local SHORT_NAME=`group_logic_get_short_name $LONG_HOSTNAME`
  ssh_control_sync_as_user root  $CONTROL_DIR/scripts/fix_admin_key.sh /root/fix_admin_key.sh $LONG_HOSTNAME
  ssh_control_run_as_user root "/root/fix_admin_key.sh $DEVICE ${SHORT_NAME} $LONG_HOSTNAME" $LONG_HOSTNAME
}

admin_control_fix_grub_these_hosts () {
  local HOSTS=$1
  local TIMEOUT=$2
  [[ $TIMEOUT != "" ]] || TIMEOUT=30

  local HOST RETURN_CODE PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Fix grub, no more info available"
        fi
      done
    else
      admin_control_fix_grub $HOST $TIMEOUT & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Fixing grub on $HOST..."
    fi
  done
}

admin_control_umount_all_parts () {
  local DEV=$1 HOST=$2

  local MOUNTS=`ssh_control_run_as_user root "mount | grep '^$DEV'" $HOST | grep $DEV | awk '{print $3}' | tr '\n' ' '`
  [[ $MOUNTS != "" ]] && ssh_control_run_as_user root "umount $MOUNTS" $HOST
}

admin_control_find_labeled_drive_by_prefix () {
  local PREFIX=$1 HOST=$2

  local SHORTNAME=`group_logic_get_short_name $HOST`
  local LABEL=${PREFIX}$SHORTNAME
  local PARTS=`ssh_control_run_as_user root "blkid | grep $LABEL" $HOST | sed 's/: LABEL=\"/:/g' | awk -F'\"' '{print $1}'`
  local PART
  for PART in $PARTS; do
    DEV=`echo $PART | awk -F':' '{print $1}'`
    LABEL=`echo $PART | awk -F':' '{print $2}'`
    echo $DEV $LABEL
  done
}


admin_control_clone_and_fix_labels () {
  # SRC_PREFIX=a|b|c|x|z
  # DEST_PREFIX=a|b|c|x|z
  # HOST=kerrigan|kgn
  local SRC_PREFIX=$1 DEST_PREFIX=$2 HOST=$3

  local SHORT_NAME SRC_DISK DEST_DISK SRC_DEV DEST_DEV
  SHORT_NAME=`group_logic_get_short_name $HOST`
  SRC_DISK=${SRC_PREFIX}$SHORT_NAME
  DEST_DISK=${DEST_PREFIX}$SHORT_NAME
  SRC_DEV=`ssh_control_run_as_user root "blkid | grep $SRC_DISK" $HOST | grep ${SRC_DISK}_boot | awk '{print $1}' | tr '\n' ' ' | sed 's/[0-9]:.*//g'`
  DEST_DEV=`ssh_control_run_as_user root "blkid | grep $DEST_DISK" $HOST | grep ${DEST_DISK}_boot | awk '{print $1}' | tr '\n' ' ' | sed 's/[0-9]:.*//g'`
  ( admin_control_clone $SRC_DEV $DEST_DEV $HOST && 
    admin_control_fix_labels $DEST_DEV $DEST_PREFIX $HOST ) > \
    "/tmp/mass_clone_${HOST}_${SRC_DISK}_${DEST_DISK}_$$.log"
  admin_control_fix_grub $HOST

  PIDS="$PIDS:$!"
  echo "Cloning $SRC_DEV to $DEST_DEV on $HOST."
}



admin_control_clone_and_fix_labels_these_hosts () {
  # SRC_PREFIX=a|b|c|x|z
  # DEST_PREFIX=a|b|c|x|z
  # HOST="kerrigan neo merlin.feralcoder.org"
  local SRC_PREFIX=$1 DEST_PREFIX=$2 HOSTS=$3

  local RETURN_CODE HOST PID SHORT_NAME SRC_DISK DEST_DISK SRC_DEV DEST_DEV PIDS LOGFILE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Mass clone, SRC_PREFIX:$SRC_PREFIX DEST_PREFIX:$DEST_PREFIX"
        fi
      done
    else
      LOGFILE=/tmp/mass_clone_${HOST}_${SRC_PREFIX}_${DEST_PREFIX}_$$.log
      echo "Logging to $LOGFILE."
      admin_control_clone_and_fix_labels $SRC_PREFIX $DEST_PREFIX $HOST > $LOGFILE &

      PIDS="$PIDS:$!"
      echo "Cloning $SRC_PREFIX to $DEST_PREFIX on $HOST."
    fi
  done
}
