#!/bin/bash


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

  local HOST RETURN_CODE
  local PIDS="" SHORT_NAME
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Mount everything, no more info available"
        fi
      done
    else
      admin_control_mount_everything $HOST &
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

  local HOST RETURN_CODE
  local PIDS="" SHORT_NAME
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Sync keys from admin, no more info available"
        fi
      done
    else
      admin_control_sync_keys_from_admin $HOST &
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
                                rsync -avH /etc/ssh/ /mnt/x\${HOST_ABBREV}_root/etc/ssh/ssh_host_*" $HOST
}


admin_control_sync_keys_to_admin_these_hosts () {
  local HOSTS=$1

  local HOST RETURN_CODE
  local PIDS="" SHORT_NAME
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Sync keys to admin, no more info available"
        fi
      done
    else
      admin_control_sync_keys_to_admin $HOST &
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
                                rsync -avH /etc/ssh/ /mnt/xax_root/etc/ssh/ssh_host_*" $HOST
}


admin_control_sync_keys_to_xax_these_hosts () {
  local HOSTS=$1

  local HOST RETURN_CODE
  local PIDS="" SHORT_NAME
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Sync keys to xax, no more info available"
        fi
      done
    else
      admin_control_sync_keys_to_admin $HOST &
      PIDS="$PIDS:$!"
      echo "Syncing keys on $HOST..."
    fi
  done
}

admin_control_bootstrap_admin () {
  local HOST=$1

  ssh_control_sync_as_user cliff ~/.git_password /home/cliff/.git_password $HOST
  ssh_control_run_as_user root "dnf -y install git" $HOST

  ssh_control_run_as_user cliff "git config --global user.name 'Cliff McIntire'; git config --global user.email 'feralcoder@gmail.com'; GIT_NAME=feralcoder; GIT_PASS=`cat ~/.git_password`; mkdir -p ~/CODE/feralcoder ; cd ~/CODE/feralcoder; git clone https://feralcoder:${GIT_PASS}@github.com/feralcoder/bootstrap-scripts; cd bootstrap-scripts" $HOST
  echo "NOW GO TO $HOST and run ~/CODE/feralcoder/bootstrap-scripts/admin.sh"
}

admin_control_make_no_crossboot () {
  local HOST=$1
  ssh_control_run_as_user root "chmod 644 /etc/grub.d/30_os-prober; grub2-mkconfig -o /boot/grub2/grub.cfg.no-crossboot; chmod 755 /etc/grub.d/30_os-prober" $HOST
}

admin_control_fix_grub () {
  local HOST=$1 TIMEOUT=$2
  [[ $TIMEOUT != "" ]] || TIMEOUT=30
  admin_control_make_no_crossboot $HOST
  local SHORT_NAME=`group_logic_get_short_name $HOST`
  ssh_control_sync_as_user root $CONTROL_DIR/scripts/fix_grub.sh /root/fix_grub.sh $HOST
  ssh_control_run_as_user root "echo $SHORT_NAME > /root/abbrev_hostname; chmod 755 /root/fix_grub.sh; TIMEOUT=$TIMEOUT /root/fix_grub.sh" $HOST
}

admin_control_clone () {
  local SRC_DEV=$1 DEST_DEV=$2 HOST=$3
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
  local DEVICE=$1 HOST=$2
  local SHORT_NAME=`group_logic_get_short_name $HOST`
  ssh_control_sync_as_user root  $CONTROL_DIR/scripts/fix_admin_key.sh /root/fix_admin_key.sh $HOST
  ssh_control_run_as_user root "/root/fix_admin_key.sh $DEVICE ${SHORT_NAME} $HOST" $HOST
}

admin_control_fix_grub_these_hosts () {
  local HOSTS=$1

  local HOST RETURN_CODE
  local PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Fix grub, no more info available"
        fi
      done
    else
      admin_control_fix_grub $HOST &
      PIDS="$PIDS:$!"
      echo "Fixing grub on $HOST..."
    fi
  done
}
