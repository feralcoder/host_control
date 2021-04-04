#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/feralcoder/host_control/control_scripts.sh



BACKUPLINK=$1 DRIVESET=$2 HOSTS=$3
[[ $BACKUPLINK == "" ]] && BACKUPLINK=01a_CentOS_8_3_Admin_Install
[[ $DRIVESET == "" ]] && DRIVESET=a
[[ $HOSTS == "" ]] && HOSTS="$ALL_HOSTS"

REBOOT_HOSTS=`group_logic_remove_self "$HOSTS"`

if [[ $DRIVESET == x ]]; then
  OPERATING_DRIVE=default
  TARGET_DRIVE=admin
else
  OPERATING_DRIVE=admin
  TARGET_DRIVE=default
fi



fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  python3 ~/CODE/feralcoder/twilio-pager/pager.py "Fallen.  Can't get up.  Installation failed at $1."
  exit 1
}

boot_to_target () {
  local TARGET=$1 HOSTS=$2
  [[ $TARGET == "admin" ]] || [[ $TARGET == "default" ]] || { echo "boot_to_target - target must be 'admin' or 'default'!"; return 1; }

  # Boot all hosts to default / admin
  os_control_boot_to_target_installation_these_hosts $TARGET "$HOSTS" || return 1
  ssh_control_wait_for_host_up_these_hosts "$HOSTS" || return 1
  os_control_assert_hosts_booted_target $TARGET "$HOSTS" || {
    echo "All stack hosts must be in their $TARGET OS to install the stack!"
    return 1
  }
}

check_active_drive () {
  SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
  NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
  [[ $NAME_SUFFIX == "" ]] && NAME_SUFFIX=default
  # if SELF NOT OPERATING DRIVE and SELF IN DO-LIST then BAIL
  ( [[ $NAME_SUFFIX != "$OPERATING_DRIVE" ]] && [[ $REBOOT_HOSTS != $HOSTS ]] ) && {
    echo "RUN THIS SCRIPT FROM AN $OPERATING_DRIVE OS!"
    echo "This host will back itself up without reboots."
    return 1
  }
  return 0
}





check_active_drive                                                  || fail_exit "check_active_drive"

echo; echo "BOOTING TO $OPERATING_DRIVE TO PERFORM RESTORE."
boot_to_target $OPERATING_DRIVE "$REBOOT_HOSTS"                     || fail_exit "boot_to_target $OPERATING_DRIVE \"$REBOOT_HOSTS\""

backup_control_backup_these_hosts "$HOSTS" "$BACKUPLINK" "$DRIVESET"                 || fail_exit "backup_control_backup_these_hosts \"$BACKUPLINK\" \"$DRIVESET\""

# DON'T NEED TO BOOT TO DEFAULT, NECESSARILY...
#os_control_boot_to_target_installation_these_hosts default "$REBOOT_HOSTS"
#os_control_assert_hosts_booted_target default "$REBOOT_HOSTS" || {
#  echo "Not all hosts booted to default OS, check the environment!"
#  exit 1
#}
