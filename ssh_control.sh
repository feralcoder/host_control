#!/bin/bash


ssh_control_get_password () {
  local PASSFILE=$1 VERIFY=$2
  # PASSFILE: if provided, will be used instead of /tmp/password_$$
  # VERIFY: if true, check and change if needed.  If false, just return file if it exists.
  [[ $PASSFILE == "" ]] && PASSFILE=/tmp/password_$$
  [[ $VERIFY == "" ]] && VERIFY=true
  local PASSWORD

  # if $PASSFILE exists and works, use it
  [[ -f $PASSFILE ]] && {
    if [[ $VERIFY == true ]]; then
      cat $PASSFILE | sudo -k -S ls >/dev/null 2>&1
      if [[ $? == 0 ]] ; then
        echo $PASSFILE
        return
      fi
    else # $PASSFILE exists and VERIFY != true
      echo $PASSFILE
      return
    fi
  }

  # either ~.password doesn't exiist, or it doesn't work and VERIFY==true
  read -s -p "Enter Password: " PASSWORD
  touch $PASSFILE
  chmod 600 $PASSFILE
  echo $PASSWORD > $PASSFILE
  echo $PASSFILE
}


ssh_control_uniqify_keys () {
  local HOST=$1
  ssh_control_run_as_user cliff "cat ~/.ssh/authorized_keys | sort | uniq > /tmp/auth_keys_$$ ; cat /tmp/auth_keys_$$ > ~/.ssh/authorized_keys" $HOST
  ssh_control_run_as_user root "cat ~/.ssh/authorized_keys | sort | uniq > /tmp/auth_keys_$$ ; cat /tmp/auth_keys_$$ > ~/.ssh/authorized_keys" $HOST
}


ssh_control_push_key () {
  local HOST=$1 PASSFILE=$2
  local DELETE_PASSFILE=false
  local REMOTE_PASSFILE=/tmp/$RANDOM

  [[ -f ~/.ssh/pubkeys/id_rsa.pub ]] && {
    local KEY=`cat ~/.ssh/pubkeys/id_rsa.pub`
  } || {
    echo "No public key to push!"
    return 1
  }

  local SSH_SETUP_CMD="[[ -d ~/.ssh/ ]] || ssh-keygen -t dsa -f ~/.ssh/id_rsa -P ''"
  local AUTH_KEYS_SETUP_CMD="echo '$KEY' >> ~/.ssh/authorized_keys; chmod 644 ~/.ssh/authorized_keys"
  ssh_control_run_as_user cliff "$SSH_SETUP_CMD; $AUTH_KEYS_SETUP_CMD" $HOST

  # TEST access to root with key, before committing to password prompting and sudo
  TESTROOT=`ssh -o NumberOfPasswordPrompts=0  root@$HOST hostname 2> /dev/null`
  [[ $? == 0 ]] || {
    # PASSFILE may have been passed to us...
    [[ $PASSFILE == "" ]] && {
      PASSFILE=`ssh_control_get_password ~/.password`
      # ONLY DELETE it if we created it...
    }

    ssh_control_sync_as_user cliff $PASSFILE $REMOTE_PASSFILE $HOST
    # Many systems disallow root login by password, and sudo through ssh is ugly...
    local SUDO_AUTH_CMD="cat $REMOTE_PASSFILE | sudo -S ls > /dev/null"
    local SSH_SETUP_CMD="sudo -S su - -c '[[ -d ~/.ssh/ ]] || ssh-keygen -t dsa -f ~/.ssh/id_rsa -P \"\"'"
    local AUTH_KEY_SETUP_CMD="echo $KEY | sudo -S su - -c 'tee -a /root/.ssh/authorized_keys' > /dev/null; sudo -S chmod 644 /root/.ssh/authorized_keys; sudo -S chown root /root/.ssh/authorized_keys"
    ssh_control_run_as_user cliff "$SUDO_AUTH_CMD; $SSH_SETUP_CMD; $AUTH_KEY_SETUP_CMD; rm $REMOTE_PASSFILE" $HOST
  }

  [[ $PASSFILE == ~/.password ]] || rm $PASSFILE    # Only delete it if we created it...
}


ssh_control_distribute_admin_key_these_hosts () {
  local HOSTS=$1

  [[ -f ~/.ssh/pubkeys/id_rsa.pub ]] && {
    local KEY=`cat ~/.ssh/pubkeys/id_rsa.pub`
  } || {
    echo "No public key to push!"
    return 1
  }

  # This part is serialized, because it requires IO from user
  local PASSFILE=`ssh_control_get_password ~/.password`
  local HOST ERROR
  for HOST in $HOSTS; do
    echo "Started Key Push for $HOST: $!"
    ssh_control_push_key $HOST $PASSFILE
    if [[ $? != 0 ]]; then
      echo "Problem pushing key for $HOST!"
      return 1
    fi
  done

  # This can be done in parallel
  local RETURN_CODE PIDS
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
            echo "UNIQIFY, no more info available"
            ERROR=true
          fi
        fi
      done
    else
      ssh_control_uniqify_keys $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Started Key Cleanup for $HOST: $!"
    fi
  done
}


ssh_control_remove_hostkey () {
  local HOST=$1
  local HOST_IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`
  local ALL_NAMES=`group_logic_get_all_names $HOST`
  local NAME
  touch ~/.ssh/known_hosts
  for NAME in $ALL_NAMES; do
    ssh-keygen -R $NAME
  done
  ssh-keygen -R $HOST_IP
}

ssh_control_get_hostkey () {
  local HOST=$1
  local HOST_IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`
  ssh-keyscan -T 30 $HOST_IP >> ~/.ssh/known_hosts
  local OUTPUT
  ( OUTPUT=`grep "$HOST_IP" ~/.ssh/known_hosts` ) || {
    echo "Failed to retrieve host key for $HOST!"
    return 1
  }

  local ALL_NAMES=`group_logic_get_all_names $HOST`
  local NAME
  for NAME in $ALL_NAMES; do
    ssh-keyscan -T 30 $NAME >> ~/.ssh/known_hosts
    ( OUTPUT=`grep "$NAME" ~/.ssh/known_hosts` ) || {
      echo "Failed to retrieve host key for $NAME!"
      return 1
    }
  done
}

ssh_control_refetch_hostkey_these_hosts () {
  local HOSTS=$1
  local HOST PIDS=""
  for HOST in $HOSTS ; do
    ssh_control_remove_hostkey $HOST
    if [[ $? != 0 ]]; then
      echo "Problem removing hostkey for HOST!"
      return 1
    fi
  done


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
            echo "refetch host key, no more info available."
            ERROR=true
          fi
        fi
      done
    else
      ssh_control_get_hostkey $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Getting host key for $HOST: $!"
    fi
  done
}

ssh_control_wait_for_host_down () {
  local HOST=$1
  local ATTEMPTS=3 INTERVAL=10

  local STATE="" INTERVAL=3
  while [[ $STATE != "Off" ]]; do
    STATE=$(ilo_power_get_state $HOST | awk '{print $3}')
    local COUNT
    for COUNT in `seq 1 3`; do
      [[ $STATE == "Off" ]] && break
      echo "$HOST still powered on, checking again in $INTERVAL seconds..."
      sleep $INTERVAL
      STATE=$(ilo_power_get_state $HOST | awk '{print $3}')
    done
  done
  echo "$HOST is powered off."
}

ssh_control_wait_for_host_up () {
  local HOST=$1
  local HOST_IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`

  local ATTEMPTS=60 INTERVAL=10

  local OUTPUT
  for i in `seq 1 $ATTEMPTS`; do
    OUTPUT=$(ssh -o ConnectTimeout=6 $HOST_IP hostname)
    if [[ $? == 0 ]]; then
      echo "$HOST is UP!"
      return 0
    else
      sleep $INTERVAL
    fi
  done

  echo $HOST DID NOT COME UP!
  return 1
}

ssh_control_wait_for_host_down_these_hosts () {
  local HOSTS=$1
  local HOST

  local RETURN_CODE PIDS=""
  local ERROR_COUNT=0
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          ERROR_COUNT=$(($ERROR_COUNT+1))
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "wait for down, no more info available"
        fi
      done
    else
      ssh_control_wait_for_host_down $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come down."
    fi
  done
  if [[ $ERROR_COUNT -gt 0 ]]; then
    echo "There were errors on $ERROR_COUNT hosts!"
    return "$ERROR_COUNT"
  fi
}

ssh_control_wait_for_host_up_these_hosts () {
  local HOSTS=$1
  local HOST

  local RETURN_CODE PIDS=""
  local ERROR_COUNT=0
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          ERROR_COUNT=$(($ERROR_COUNT+1))
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "wait for up, no more info available"
        fi
      done
    else
      ssh_control_wait_for_host_up $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come up."
    fi
  done
  if [[ $ERROR_COUNT -gt 0 ]]; then
    echo "There were errors on $ERROR_COUNT hosts!"
    return "$ERROR_COUNT"
  fi
}

ssh_control_run_as_user () {
  local USER=$1 COMMAND=$2 HOST=$3
  local HOST_IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`

  local OUTPUT CODE
  OUTPUT=$(ssh -o ConnectTimeout=10 -l $USER $HOST_IP "$COMMAND")
  CODE=$?
  echo "Output from $HOST:"
  echo "$OUTPUT"
  return $CODE
}

ssh_control_run_as_user_these_hosts () {
  local USER=$1 COMMAND=$2 HOSTS=$3
  local HOST

  local ERROR RETURN_CODE PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'` 'all_reaped'; do
        if [[ $PID == 'all_reaped' ]]; then
          [[ $ERROR == "" ]] && return 0 || return 1
        else
          wait ${PID} >/dev/null 2>&1
          RETURN_CODE=$?
          if [[ $RETURN_CODE != 0 ]]; then
            echo "Return code for PID $PID: $RETURN_CODE"
            echo "Run as user: COMMAND:$COMMAND"
            ERROR=true
          fi
        fi
      done
    else
      ssh_control_run_as_user $USER "$COMMAND" $HOST & >/dev/null 2>&1
      PIDS="$PIDS:$!"
      [[ $DEBUG == "" ]] || echo "Running \"$COMMAND\" as $USER on $HOST, PID: $!"
    fi
  done
}

ssh_control_sync_as_user () {
  local USER=$1 SOURCE=$2 DEST=$3 HOST=$4
  local HOST_IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`

  OUTPUT=$(rsync -avH $SOURCE $USER@$HOST_IP:$DEST)
  [[ $DEBUG == "" ]] || echo $SOURCE synced to $HOST:
  [[ $DEBUG == "" ]] || echo "$OUTPUT"
}

ssh_control_sync_as_user_these_hosts () {
  local USER=$1 SOURCE=$2 DEST=$3 HOSTS=$4
  local HOST



  local ERROR RETURN_CODE PIDS
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'` 'all_reaped'; do
        if [[ $PID == 'all_reaped' ]]; then
          [[ $ERROR == "" ]] && return 0 || return 1
        else
          wait ${PID} >/dev/null 2>&1
          RETURN_CODE=$?
          if [[ $RETURN_CODE != 0 ]]; then
            echo "Return code for PID $PID: $RETURN_CODE"
            echo "syncing USER:$USER SOURCE:$SOURCE DEST:$DEST"
            ERROR=true
          fi
        fi
      done
    else
      ssh_control_sync_as_user $USER $SOURCE $DEST $HOST & >/dev/null 2>&1
      PIDS="$PIDS:$!"
      [[ $DEBUG == "" ]] || echo "Syncing $SOURCE to $HOST, PID: $!"
    fi
  done
}
