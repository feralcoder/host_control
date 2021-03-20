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
[[ $BACKUPLINK == "" ]] && BACKUPLINK=01_CentOS_8_3_Admin_Install
[[ $DRIVESET == "" ]] && DRIVESET=a
[[ $HOSTS == "" ]] && HOSTS="$ALL_HOSTS"

# This script will restore all hard drive OS's
#   by default from Updated Centos8 Admin images to DriveA
# Run from admin box (yoda)

# root users also need to know all hosts, for restor rsyncs
#for HOST in $HOSTS; do
#  ssh_control_run_as_user root ". ~cliff/CODE/feralcoder/host_control/control_scripts.sh; ssh_control_refetch_hostkey_these_hosts \"$HOSTS\"" $HOST
#done
#
#ssh_control_run_as_user_these_hosts root "[[ -f ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa" "$HOSTS"
#ssh_control_run_as_user_these_hosts root "cat ~/.ssh/id_rsa.pub" "$HOSTS" | grep '^ssh' > /tmp/root_pubs
#ssh_control_sync_as_user_these_hosts root /tmp/root_pubs /tmp/root_pubs "$HOSTS"
#ssh_control_run_as_user_these_hosts root "cat ~/.ssh/authorized_keys /tmp/root_pubs | sort | uniq > /tmp/root_pubs_$$ ; cat /tmp/root_pubs_$$ > ~/.ssh/authorized_keys" "$HOSTS"

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
  echo "RUN THIS SCRIPT FROM AN $OPERATING_DRIVE OS!"
  echo "This host will back itself up without reboots."
  exit 1
}


os_control_boot_to_target_installation_these_hosts $OPERATING_DRIVE "$REBOOT_HOSTS"
os_control_assert_hosts_booted_target $OPERATING_DRIVE "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to $OPERATING_DRIVE OS, check the environment!"
  exit 1
}

reset_OSDs () {
  MAP=`ceph_control_show_map`
  ceph_control_wipe_LVM_OSDs_from_map_these_hosts "$MAP" "$COMPUTE_HOSTS" || exit 1
  ceph_control_create_LVM_OSDs_from_map_these_hosts "$MAP" "$COMPUTE_HOSTS" || exit 1
}

reset_OSDs

SOURCEDIR=""  # Default backup directory can change in backup scripts.
backup_control_restore_all "$BACKUPLINK" "$SOURCEDIR" "$DRIVESET"
admin_control_fix_grub_these_hosts "$HOSTS"

echo; echo "GRUB MAY BE BROKEN ON TARGET DRIVE - if reboot fails, then access from $OPERATING_DRIVE GRUB, then fix grub."
os_control_boot_to_target_installation_these_hosts $TARGET_DRIVE "$STACK_HOSTS"
os_control_assert_hosts_booted_target $TARGET_DRIVE "$REBOOT_HOSTS" || {
  echo "Not all hosts booted to $TARGET_DRIVE OS, check the environment!"
  exit 1
}
admin_control_fix_grub_these_hosts "$HOSTS"
