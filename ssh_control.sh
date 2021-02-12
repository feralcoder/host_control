#!/bin/bash

. ilo_common.sh
. ilo_power.sh
. ilo_boot.sh
. ilo_boot_target.sh


ssh_control_uniqify_keys () {
  local HOST=$1
  ssh_control_run_as_user cliff "cat ~/.ssh/authorized_keys | sort | uniq > /tmp/auth_keys_$$ ; cat /tmp/auth_keys_$$ > ~/.ssh/authorized_keys" $HOST
  ssh_control_run_as_user root "cat ~/.ssh/authorized_keys | sort | uniq > /tmp/auth_keys_$$ ; cat /tmp/auth_keys_$$ > ~/.ssh/authorized_keys" $HOST
}

ssh_control_push_key () {
  local HOST=$1

  [[ -f ~/.ssh/pubkeys/id_rsa.pub ]] && {
    local KEY=`cat ~/.ssh/pubkeys/id_rsa.pub`
  } || {
    echo "No public key to push!"
    return 1
  }

  ssh_control_run_as_user cliff "echo '$KEY' >> ~/.ssh/authorized_keys; chmod 644 ~/.ssh/authorized_keys" $HOST

  # TEST access to root with key, before committing to sudo entries...
  OUTPUT=`ssh -o NumberOfPasswordPrompts=0  root@$HOST hostname`
  [[ $? == 0 ]] || {
    # Many systems disallow root login by password, and sudo through ssh is ugly...
    ssh_control_run_as_user cliff "echo $KEY > /tmp/key_$$; sudo -S cat /root/.ssh/authorized_keys /tmp/key_$$ > /tmp/root_auth_keys_$$; sudo -S mv /tmp/root_auth_keys_$$ /root/.ssh/authorized_keys; sudo -S chmod 644 /root/.ssh/authorized_keys; sudo -S chown root /root/.ssh/authorized_keys" $HOST
  }
}

ssh_control_distribute_admin_key_these_hosts () {
  local PIDS="" HOST

  [[ -f ~/.ssh/pubkeys/id_rsa.pub ]] && {
    local KEY=`cat ~/.ssh/pubkeys/id_rsa.pub`
  } || {
    echo "No public key to push!"
    return 1
  }

  # This part is serialized, because it requires IO from user
  for HOST in $@; do
    echo "Started Key Push for $HOST: $!"
    ssh_control_push_key $HOST
  done

  # This can be done in parallel
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ssh_control_uniqify_keys $HOST &
      PIDS="$PIDS:$!"
      echo "Started Key Cleanup for $HOST: $!"
    fi
  done
}

ssh_control_get_all_names () {
  local HOST=$1
  local HOST_IP=`getent hosts $HOST | awk '{print $1}'`
  local HOSTNAMES=`grep "$HOST_IP " /etc/hosts | sed 's/^[^ ]*[ ]*//g'`
  echo $HOSTNAMES
}

ssh_control_remove_hostkey () {
  local HOST=$1
  local HOST_IP=`getent hosts $HOST | awk '{print $1}'`
  local ALL_NAMES=`ssh_control_get_all_names $HOST`
  local NAME
  for NAME in $ALL_NAMES; do
    ssh-keygen -R $NAME
  done
  ssh-keygen -R $HOST_IP
}

ssh_control_get_hostkey () {
  local HOST=$1
  local HOST_IP=`getent hosts $HOST | awk '{print $1}'`
  ssh-keyscan -T 30 $HOST_IP >> ~/.ssh/known_hosts
  local OUTPUT
  ( OUTPUT=`grep "$HOST_IP" ~/.ssh/known_hosts` ) || {
    echo "Failed to retrieve host key for $HOST!"
    return 1
  }

  local ALL_NAMES=`ssh_control_get_all_names $HOST`
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
  local PIDS="" HOST HOST_IP
  for HOST in $@ ; do
    ssh_control_remove_hostkey $HOST
  done
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      HOST_IP=`getent hosts $HOST | awk '{print $1}'`
      ssh_control_get_hostkey $HOST &
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
  local HOST_IP=`getent hosts $HOST | awk '{print $1}'`

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
  local HOST

  local PIDS=""
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ssh_control_wait_for_host_down $HOST &
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come down."
    fi
  done
}

ssh_control_wait_for_host_up_these_hosts () {
  local HOST

  local PIDS=""
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ssh_control_wait_for_host_up $HOST &
      PIDS="$PIDS:$!"
      echo "Waiting for $HOST to come up."
    fi
  done
}

ssh_control_run_as_user () {
  local USER=$1 COMMAND=$2 HOST=$3
  local HOST_IP=`getent hosts $HOST | awk '{print $1}'`

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

  local PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ssh_control_run_as_user $USER "$COMMAND" $HOST &
      PIDS="$PIDS:$!"
      echo "Running \"$COMMAND\" as $USER on $HOST"
    fi
  done
}

ssh_control_sync_as_user () {
  local USER=$1 SOURCE=$2 DEST=$3 HOST=$4
  local HOST_IP=`getent hosts $HOST | awk '{print $1}'`

  OUTPUT=$(rsync -avH $SOURCE $USER@$HOST_IP:$DEST)
  echo $SOURCE synced to $HOST:
  echo "$OUTPUT"
}

ssh_control_sync_as_user_to_these_hosts () {
  local USER=$1 SOURCE=$2 DEST=$3 HOSTS=$4
  local HOST

  local PIDS=""
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ssh_control_sync_as_user $USER $SOURCE $DEST $HOST &
      PIDS="$PIDS:$!"
      echo "Syncing $SOURCE to $HOST"
    fi
  done
}

ssh_control_wait_for_host_up_all_hosts () {
  ssh_control_wait_for_host_up_these_hosts $ALL_HOSTS
}
ssh_control_wait_for_host_down_all_hosts () {
  ssh_control_wait_for_host_down_these_hosts $ALL_HOSTS
}

ssh_control_sync_as_user_to_all_hosts () {
  local USER=$1 SOURCE=$2 DEST=$3
  ssh_control_sync_as_user_to_these_hosts $USER $SOURCE $DEST "$ALL_HOSTS"
}
ssh_control_run_as_user_on_all_hosts () {
  local USER=$1 COMMAND=$2
  ssh_control_run_as_user_these_hosts $USER $COMMAND "$ALL_HOSTS"
}
