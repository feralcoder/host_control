#!/bin/bash
ADMIN_SETUP_SOURCE="${BASH_SOURCE[0]}"
ADMIN_SETUP_DIR=$( dirname $ADMIN_SETUP_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

BACKUPLINK=$1
[[ $BACKUPLINK == "" ]] && BACKUPLINK=01_CentOS_8_3_Admin_Install

# This script will backup all hard drive OS's
#   by default to Updated Centos8 Admin images
# Run from admin box (yoda)

os_control_boot_to_target_installation_these_hosts admin "$STACK_HOSTS" # Will skip localhost
backup_control_backup_all 01_CentOS_8_3_Admin_Install
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS" # Will skip localhost

admin_control_fix_grub_these_hosts "$ALL_HOSTS"
