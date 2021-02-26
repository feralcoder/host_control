#!/bin/bash
ADMIN_SETUP_SOURCE="${BASH_SOURCE[0]}"
ADMIN_SETUP_DIR=$( dirname $ADMIN_SETUP_SOURCE )

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
  return 1
}

os_control_boot_to_target_installation_these_hosts admin "$ALL_HOSTS" # Will skip localhost
backup_control_restore_all 01_CentOS_8_3_Admin_Install
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS" # Will skip localhost

admin_control_fix_grub_these_hosts "$ALL_HOSTS"
