#!/bin/bash

os_control_graceful_stop () {
  local HOST=$1

  ssh_control_run_as_user root poweroff $HOST
  OUTPUT=`ssh_control_wait_for_host_down $HOST`
  [[ $? == 0 ]] || ilo_power_off $HOST
  OUTPUT=`ssh_control_wait_for_host_down $HOST`
  [[ $? == 0 ]] || return 1
}

os_control_graceful_stop_these_hosts () {
  local HOSTS=$1

  if [[ $UNSAFE == "" ]]; then
    HOSTS=$(group_logic_remove_self "$HOSTS")
  fi

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
          echo "Graceful stop, no more info available"
        fi
      done
    else
      os_control_graceful_stop $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Stopping $HOST..."
    fi
  done
}


# STATE="BOOTED|IN_BETWEEN|OFF"
os_control_get_system_state () {
  local HOST=$1

  local LOGIN_STATE STATE RETVAL
  local PWR_STATE=$(ilo_power_get_state $HOST | awk '{print $3}')

  if [[ $PWR_STATE == On ]]; then
    HOSTNAME=`ssh_control_run_as_user root hostname $HOST`
    RETVAL=$?
    if [[ $RETVAL == 0 ]]; then
      STATE="BOOTED"
    else
      STATE="IN_BETWEEN"
      echo $STATE
      return 1
    fi
  else
    STATE="OFF"
    echo $STATE
    return 2
  fi
  echo $STATE
}

# RETURN "$BOOTDEV:$INSTALLATION=admin|default"
os_control_boot_info () {
  local HOST=$1

  local INSTALLATION HOSTNAME BOOTDEV
  local STATE=$(os_control_get_system_state $HOST)
  if [[ $STATE == "BOOTED" ]]; then
    HOSTNAME=$(ssh_control_run_as_user root hostname $HOST)
    if [[ $(echo $HOSTNAME | awk -F'.' '{print $1}' | awk -F'-' '{print $2}') == "admin" ]]; then
      INSTALLATION="admin"
    else
      INSTALLATION="default"
    fi
    BOOTDEV=$(ssh_control_run_as_user root "mount" $HOST | grep ' /boot ' | awk '{print $1}')
  elif [[ $STATE == "IN_BETWEEN" ]]; then
    echo "$HOST is not BOOTED!"
    return 1
  elif [[ $STATE == "OFF" ]]; then
    echo "$HOST is OFF!"
    return 2
  else
    echo "$HOST is in UNKNON STATE!"
    return 128
  fi

  echo "$BOOTDEV:$INSTALLATION"
}

os_control_boot_info_these_hosts () {
  local HOSTS=$1

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
          echo "Boot info, no more info available"
        fi
      done
    else
      echo "$HOST is booted to: $(os_control_boot_info $HOST)" & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Getting OS Boot Info For $HOST..."
    fi
  done
}

os_control_boot_to_target_installation () {
  # $TARGET==[admin|default]
  local TARGET=$1 HOST=$2

  local OUTPUT OS_BOOT_INFO RETVAL
  [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, getting boot_info for $HOST" 2>&1
  OS_BOOT_INFO=`os_control_boot_info $HOST`
  RETVAL=$?
  [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, boot_info: $OS_BOOT_INFO" 2>&1
  [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, return value: $RETVAL" 2>&1

  # IF IN_BETWEEN OFF and BOOTED, GET TO A DETERMINATE STATE
  if [[ $RETVAL == 1 ]]; then
    [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, $HOST may be booting, about to wait..." 2>&1
    # host may be booting...
    OUTPUT=`ssh_control_wait_for_host_up $HOST`
    RETVAL=$?
    [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, $HOST is up..." 2>&1
    if [[ $RETVAL != 0 ]]; then
      [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, $HOST never booted, kicking over" 2>&1
      OUTPUT=$(ilo_power_off $HOST)
      OUTPUT=`ssh_control_wait_for_host_down $HOST`
      [[ $? == 0 ]] || { echo ERROR shutting down $HOST!; return 1; }
    fi
    OS_BOOT_INFO=`os_control_boot_info $HOST`
    RETVAL=$?
  fi

  # HOST SHOULD BE OFF OR BOOTED AT THIS POINT
  if [[ $RETVAL == 0 ]]; then
    [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, $HOST is booted" 2>&1
    # host is booted
    if [[ $(echo $OS_BOOT_INFO | awk -F':' '{print $2}') == "$TARGET" ]]; then
      # WE'RE DONE!
      echo "$HOST is booted to $TARGET"
      return
    else
      [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, $HOST is booted to wrong $TARGET" 2>&1
      # POWER OFF HOST
      OUTPUT=$(ssh_control_run_as_user root poweroff $HOST)
      OUTPUT=`ssh_control_wait_for_host_down $HOST`
      if [[ $? != 0 ]]; then
        [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, powering off $HOST" 2>&1
        OUTPUT=$(ilo_power_off $HOST)
        OUTPUT=`ssh_control_wait_for_host_down $HOST`
        [[ $? == 0 ]] || { echo ERROR shutting down $HOST!; return 1; }
      fi
    fi
  elif [[ $RETVAL != 2 ]]; then
    # HOST SHOULD BE OFF BY NOW
    echo "$HOST is in UNKNOWN STATE"
    return 1
  fi

  [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, getting os_control_boot_info $HOST" 2>&1
  OS_BOOT_INFO=`os_control_boot_info $HOST`
  RETVAL=$?
  [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, got os_control_boot_info $HOST" 2>&1


  local HW_GEN
  # HOST SHOULD BE OFF AT THIS POINT
  if [[ $RETVAL == 2 ]]; then
    [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, now booting $HOST to $TARGET" 2>&1
    HW_GEN=`ilo_control_get_hw_gen $HOST`
    if [[ $TARGET == "admin" ]]; then
      if [[ $HW_GEN == "6" ]]; then
        [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, now booting ILO2 $HOST to $TARGET" 2>&1
        OUTPUT=$(ilo_boot_target_once_ilo2 $DEV_USB $HOST)
      elif [[ $HW_GEN == "8" ]]; then
        [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, now booting ILO4 $HOST to $TARGET" 2>&1
        OUTPUT=$(ilo_boot_target_once_ilo4 $DEV_USB $HOST)
      else
        [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, $HOST isn't ILO2 or ILO4, check your wreck" 2>&1
      fi
    else
      [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, powering on $HOST" 2>&1
      OUTPUT=$(ilo_power_on $HOST)
    fi
    [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, waiting for $HOST to come up" 2>&1
    OUTPUT=`ssh_control_wait_for_host_up $HOST`
    if [[ $? != 0 ]]; then
      OUTPUT=$(ilo_power_on $HOST)
      OUTPUT=`ssh_control_wait_for_host_up $HOST`
      [[ $? == 0 ]] || { echo "ERROR BOOTING $HOST!"; return 1; }
    fi
  else
    echo "$HOST should be OFF and is NOT!"
    return 1
  fi

  [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, checking $HOST boot OS..." 2>&1
  OS_BOOT_INFO=`os_control_boot_info $HOST`
  RETVAL=$?

  # HOST SHOULD BE BOOTED TO $TARGET AT THIS POINT
  if [[ $RETVAL == 0 ]]; then
    [[ $DEBUG == "" ]] || echo "In os_control_boot_to_target_installation, $HOST boot_info: $OS_BOOT_INFO..." 2>&1
    if [[ $(echo $OS_BOOT_INFO | awk -F':' '{print $2}') == "$TARGET" ]]; then
      # WE'RE DONE!
      echo "$HOST is booted to $TARGET"
      return
    else
      echo "$HOST is BOOTED but OS is NOT $TARGET!"
      return 1
    fi
  else
    echo "$HOST should be BOOTED and is NOT!"
    return 1
  fi
}

os_control_boot_to_target_installation_these_hosts () {
  local TARGET=$1 HOSTS=$2

  if [[ $UNSAFE == "" ]]; then
    HOSTS=$(group_logic_remove_self "$HOSTS")
  fi

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
          echo "Boot to target installation: TARGET:$TARGET"
        fi
      done
    else
      os_control_boot_to_target_installation $TARGET $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Booting $HOST to $TARGET.  This may take a while..."
    fi
  done
}


os_control_repoint_repos_to_feralcoder () {
  local HOST=$1

  cd ~/CODE/feralcoder
  [[ -d repo-fetcher ]] && {
    echo "Syncing repo-fetcher code to $HOST."
    ssh_control_sync_as_user root ~/CODE/feralcoder/repo-fetcher/ /tmp/repo-fetcher/ $HOST
    #ssh_control_sync_as_user root ~/CODE/feralcoder/repo-fetcher/set_client_repos.sh /tmp/ $HOST
    #ssh_control_sync_as_user root ~/CODE/feralcoder/repo-fetcher/feralcoder.repo /tmp/ $HOST
    echo "Running repo-fetcher/set_client_repos.sh on $HOST."
    ssh_control_run_as_user root "/tmp/repo-fetcher/set_client_repos.sh" $HOST
  } || {
    echo "repo-fetcher checkout not on this host."
    echo "It's suggested you run this on dumbledore, the repo server."
    echo "Or run 'os_control_checkout_repofetcher \$TARGET' to check it out."
  }
}

os_control_checkout_repofetcher () {
  local HOST=$1

  echo "Checking out repo-fetcher on $REPO_HOST"
  ssh_control_sync_as_user cliff ~/.git_password ~/.git_password $REPO_HOST
  ssh_control_run_as_user cliff "cd ~/CODE/feralcoder; [[ -d repo-fetcher ]] && echo repo-fetcher already checked out on \$HOST || git clone https://feralcoder:\`cat ~/.git_password\`@github.com/feralcoder/repo-fetcher.git" $HOST
  ssh_control_run_as_user cliff "cd ~/CODE/feralcoder/repo-fetcher && git pull" $HOST
}

os_control_update_repo_mirror () {
  local HOST=$1

  echo "Checking out latest repo-fetchen on $HOST"
  os_control_checkout_repofetcher $HOST
  echo "Running repo-fetcher update on $HOST, see logs in /tmp/repo-fetcher_update_$NOW.log"
  ssh_control_run_as_user root "/home/cliff/CODE/feralcoder/repo-fetcher/update.sh | tee /tmp/repo-fetcher_update_$NOW.log" $HOST
}

os_control_setup_repo_mirror () {
  local HOST=$1

  echo "Checking out latest repo-fetchen on $HOST"
  os_control_checkout_repofetcher $HOST
  echo "Running repo-fetcher setup on $HOST, see logs in /tmp/repo-fetcher_setup_$NOW.log"
  ssh_control_run_as_user root "/home/cliff/CODE/feralcoder/repo-fetcher/setup.sh | tee /tmp/repo-fetcher_setup_$NOW.log" $HOST
}

os_control_repoint_repos_to_feralcoder_these_hosts () {
  local HOSTS=$1

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
          echo "Checkout repofetcher, no more info available"
        fi
      done
    else
      os_control_repoint_repos_to_feralcoder $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Repointing $HOST's OS package repos to feralcoder..."
    fi
  done
}

os_control_assert_hosts_booted_target () {
  local TARGET=$1 HOSTS=$2

  OUTPUT=`os_control_boot_info_these_hosts "$HOSTS"`
  local HOST
  for HOST in $HOSTS; do
    echo "$OUTPUT" | grep "$HOST is booted to: .*$TARGET" || {
      echo "Not all hosts are booted to $TARGET OS!"
      return 1
    }
  done
  echo "Hosts are booted to $TARGET OS!"
}
