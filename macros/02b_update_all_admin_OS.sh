#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. $MACRO_DIR/../control_scripts.sh

# This script powers off everything before updating.
# This is to reduce problems with indeterminate state, ie mounts, etc.

HOSTS=$1
[[ $HOSTS != "" ]] || {
  echo "No hosts provided.  Please call script with a host list to update."
  exit 1
}

# This will boot to admin all OTHER hosts - RUN FROM ADMIN SERVER (yoda?)
SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
[[ $NAME_SUFFIX == "admin" ]] || {
  echo "RUN THIS SCRIPT FROM AN ADMIN OS!"
  echo "This host will back itself up without reboots."
  exit 1
}

ilo_control_refetch_ilo_hostkey_these_hosts "$ALL_HOSTS"

REBOOT_HOSTS=`group_logic_remove_self "$HOSTS"`
ilo_power_off_these_hosts "$REBOOT_HOSTS"
os_control_boot_to_target_installation_these_hosts admin "$REBOOT_HOSTS"
os_control_assert_hosts_booted_target admin "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to admin OS, check the environment!"
  exit 1
}
. $MACRO_DIR/02a_hosts_update.sh "$HOSTS"
