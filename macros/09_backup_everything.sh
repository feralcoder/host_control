#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

BACKUPLINK=$1 DRIVESET=$2 HOSTS=$3
[[ $BACKUPLINK == "" ]] && BACKUPLINK=01_CentOS_8_3_Admin_Install
[[ $DRIVESET == "" ]] && DRIVESET=a
[[ $HOSTS == "" ]] && HOSTS="$ALL_HOSTS"

# This script will backup all hard drive OS's
#   by default: DriveA to Updated Centos8 Admin images
# Run from admin box (yoda)

# root users also need to know all hosts, for backup rsyncs
#for HOST in $ALL_HOSTS; do
#  ssh_control_run_as_user root ". ~cliff/CODE/feralcoder/host_control/control_scripts.sh; ssh_control_refetch_hostkey_these_hosts \"$ALL_HOSTS\"" $HOST
#done
#
#ssh_control_run_as_user_these_hosts root "[[ -f ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa" "$ALL_HOSTS"
#ssh_control_run_as_user_these_hosts root "cat ~/.ssh/id_rsa.pub" "$ALL_HOSTS" | grep '^ssh' > /tmp/root_pubs
#ssh_control_sync_as_user_these_hosts root /tmp/root_pubs /tmp/root_pubs "$ALL_HOSTS"
#ssh_control_run_as_user_these_hosts root "cat ~/.ssh/authorized_keys /tmp/root_pubs | sort | uniq > /tmp/root_pubs_$$ ; cat /tmp/root_pubs_$$ > ~/.ssh/authorized_keys" "$ALL_HOSTS"

if [[ $DRIVESET == x ]]; then
  OPERATING_DRIVE=default
  TARGET_DRIVE=admin
else
  OPERATING_DRIVE=admin
  TARGET_DRIVE=default
fi


SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`

[[ $NAME_SUFFIX == "" ]] && NAME_SUFFIX=default
[[ $NAME_SUFFIX == "$OPERATING_DRIVE" ]] || {
  echo "RUN THIS SCRIPT FROM THE $OPERATING_DRIVE OS!"
  echo "This host will back itself up without reboots."
  exit 1
}

REBOOT_HOSTS=`group_logic_remove_self "$ALL_HOSTS"`
os_control_boot_to_target_installation_these_hosts $OPERATING_DRIVE "$REBOOT_HOSTS"
os_control_assert_hosts_booted_target $OPERATING_DRIVE "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to $OPERATING_DRIVE OS, check the environment!"
  exit 1
}

backup_control_backup_all $BACKUPLINK $DRIVESET

# DON'T NEED TO BOOT TO DEFAULT, NECESSARILY...
#os_control_boot_to_target_installation_these_hosts default "$REBOOT_HOSTS"
#os_control_assert_hosts_booted_target default "$REBOOT_HOSTS" || {
#  echo "Not all hosts booted to default OS, check the environment!"
#  exit 1
#}

# WHY?
# admin_control_fix_grub_these_hosts "$ALL_HOSTS"
