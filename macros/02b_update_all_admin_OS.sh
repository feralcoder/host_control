#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. $MACRO_DIR/../control_scripts.sh

# This script powers off everything before updating.
# This is to reduce problems with indeterminate state, ie mounts, etc.

# This will boot to admin all OTHER hosts - RUN FROM ADMIN SERVER (yoda?)
SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
[[ $NAME_SUFFIX == "admin" ]] || {
  echo "RUN THIS SCRIPT FROM AN ADMIN OS!"
  echo "This host will back itself up without reboots."
  return 1
}


REBOOT_HOSTS=`group_logic_remove_self "$ALL_HOSTS"`
ilo_power_off_these_hosts "$REBOOT_HOSTS"
os_control_boot_to_target_installation_these_hosts admin "$REBOOT_HOSTS"
os_control_assert_hosts_booted_target admin "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to admin OS, check the environment!"
  return 1
}
. $MACRO_DIR/00_hosts_update.sh
