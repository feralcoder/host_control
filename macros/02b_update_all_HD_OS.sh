#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. $MACRO_DIR/../control_scripts.sh

# This script powers off everything before updating.
# This is to reduce problems with indeterminate state, ie mounts, etc.

HOSTS=$1
[[ $HOSTS != "" ]] || {
  echo "No hosts provided.  Please call script with a host list to update."
  exit 1
}

# This will boot to default all OTHER hosts - RUN FROM ADMIN SERVER (yoda?)
SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
[[ $NAME_SUFFIX == "admin" ]] && {
  echo "RUN THIS SCRIPT FROM A DEFAULT OS!"
  echo "This host will back itself up without reboots."
  return 1
}


REBOOT_HOSTS=`group_logic_remove_self "$HOSTS"`
ilo_power_off_these_hosts "$REBOOT_HOSTS"
os_control_boot_to_target_installation_these_hosts default "$REBOOT_HOSTS"
os_control_assert_hosts_booted_target default "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to default OS, check the environment!"
  return 1
}
. $MACRO_DIR/02a_hosts_update.sh "$HOSTS"
