#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

BACKUPLINK=$1
[[ $BACKUPLINK == "" ]] && BACKUPLINK=01_CentOS_8_3_Admin_Install

# This script will backup all hard drive OS's
#   by default to Updated Centos8 Admin images
# Run from admin box (yoda)

SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
[[ $NAME_SUFFIX == "admin" ]] || {
  echo "RUN THIS SCRIPT FROM AN ADMIN OS!"
  echo "This host will back itself up without reboots."
  return 1
}
os_control_boot_to_target_installation_these_hosts admin "$ALL_HOSTS" # Will skip localhost
backup_control_backup_all 01_CentOS_8_3_Admin_Install
os_control_boot_to_target_installation_these_hosts default "$ALL_HOSTS" # Will skip localhost

admin_control_fix_grub_these_hosts "$ALL_HOSTS"
