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

# This script will backup all hard drive OS's
#   by default: DriveA to Updated Centos8 Admin images
# Run from admin box (yoda)

if [[ $DRIVESET == x ]]; then
  OPERATING_DRIVE=default
  TARGET_DRIVE=admin
else
  OPERATING_DRIVE=admin
  TARGET_DRIVE=default
fi


SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`

REBOOT_HOSTS=`group_logic_remove_self "$HOSTS"`

[[ $NAME_SUFFIX == "" ]] && NAME_SUFFIX=default
# if SELF NOT OPERATING DRIVE and SELF IN DO-LIST then BAIL
( [[ $NAME_SUFFIX != "$OPERATING_DRIVE" ]] && [[ $REBOOT_HOSTS != $HOSTS ]] ) && {
  echo "RUN THIS SCRIPT FROM THE $OPERATING_DRIVE OS!"
  echo "This host will back itself up without reboots."
  exit 1
}

os_control_boot_to_target_installation_these_hosts $OPERATING_DRIVE "$REBOOT_HOSTS"
os_control_assert_hosts_booted_target $OPERATING_DRIVE "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to $OPERATING_DRIVE OS, check the environment!"
  exit 1
}

backup_control_backup_all "$BACKUPLINK" "$DRIVESET"

# DON'T NEED TO BOOT TO DEFAULT, NECESSARILY...
#os_control_boot_to_target_installation_these_hosts default "$REBOOT_HOSTS"
#os_control_assert_hosts_booted_target default "$REBOOT_HOSTS" || {
#  echo "Not all hosts booted to default OS, check the environment!"
#  exit 1
#}

# WHY?
# admin_control_fix_grub_these_hosts "$HOSTS"
