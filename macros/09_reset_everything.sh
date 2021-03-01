#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

BACKUPLINK=$1
[[ $BACKUPLINK == "" ]] && BACKUPLINK=01_CentOS_8_3_Admin_Install

# This script will restore all hard drive OS's
#   by default from Updated Centos8 Admin images
# Run from admin box (yoda)

SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
[[ $NAME_SUFFIX == "admin" ]] || {
  echo "RUN THIS SCRIPT FROM AN ADMIN OS!"
  echo "This host will back itself up without reboots."
  exit 1
}


REBOOT_HOSTS=`group_logic_remove_self "$ALL_HOSTS"`
os_control_boot_to_target_installation_these_hosts admin "$REBOOT_HOSTS"
os_control_assert_hosts_booted_target admin "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to admin OS, check the environment!"
  exit 1
}

backup_control_restore_all 01_CentOS_8_3_Admin_Install

os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
os_control_assert_hosts_booted_target default "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to default OS, check the environment!"
  exit 1
}

admin_control_fix_grub_these_hosts "$ALL_HOSTS"
