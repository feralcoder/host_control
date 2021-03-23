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

REBOOT_HOSTS=`group_logic_remove_self "$HOSTS"`

if [[ $DRIVESET == x ]]; then
  OPERATING_DRIVE=default
  TARGET_DRIVE=admin
else
  OPERATING_DRIVE=admin
  TARGET_DRIVE=default
fi



fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  python3 ~/CODE/feralcoder/twilio-pager/pager.py "Fallen.  Can't get up.  Installation failed at $1."
  exit 1
}

boot_to_target () {
  local TARGET=$1 HOSTS=$2
  [[ $TARGET == "admin" ]] || [[ $TARGET == "default" ]] || { echo "boot_to_target - target must be 'admin' or 'default'!"; return 1; }

  # Boot all hosts to default / admin
  os_control_boot_to_target_installation_these_hosts $TARGET "$HOSTS" || return 1
  ssh_control_wait_for_host_up_these_hosts "$HOSTS" || return 1
  os_control_assert_hosts_booted_target $TARGET "$HOSTS" || {
    echo "All stack hosts must be in their $TARGET OS to install the stack!"
    return 1
  }
}

check_active_drive () {
  SELFNAME_SHORT=`hostname | awk -F'.' '{print $1}'`
  NAME_SUFFIX=`echo $SELFNAME_SHORT | awk -F'-' '{print $2}'`
  [[ $NAME_SUFFIX == "" ]] && NAME_SUFFIX=default
  # if SELF NOT OPERATING DRIVE and SELF IN DO-LIST then BAIL
  ( [[ $NAME_SUFFIX != "$OPERATING_DRIVE" ]] && [[ $REBOOT_HOSTS != $HOSTS ]] ) && {
    echo "RUN THIS SCRIPT FROM AN $OPERATING_DRIVE OS!"
    echo "This host will back itself up without reboots."
    return 1
  }
  return 0
}

reset_OSDs () {
  MAP=`ceph_control_show_map`
  ceph_control_wipe_LVM_OSDs_from_map_these_hosts "$MAP" "$COMPUTE_HOSTS" || return 1
  ceph_control_create_LVM_OSDs_from_map_these_hosts "$MAP" "$COMPUTE_HOSTS" || return 1
}




check_active_drive                                                  || fail_exit "check_active_drive"

echo; echo "BOOTING TO $OPERATING_DRIVE TO PERFORM RESTORE."
boot_to_target $OPERATING_DRIVE "$REBOOT_HOSTS"                     || fail_exit "boot_to_target $OPERATING_DRIVE \"$REBOOT_HOSTS\""

reset_OSDs                                                          || fail_exit "reset_OSDs"

SOURCEDIR=""  # Default backup directory can change in backup scripts, can override here...
backup_control_restore_all "$BACKUPLINK" "$SOURCEDIR" "$DRIVESET"   || fail_exit "backup_control_restore_all \"$BACKUPLINK\" \"$SOURCEDIR\" \"$DRIVESET\""
admin_control_fix_grub_these_hosts "$HOSTS"                         || fail_exit "admin_control_fix_grub_these_hosts \"$HOSTS\""

echo; echo "GRUB MAY BE BROKEN ON TARGET DRIVE - if reboot fails, then access from $OPERATING_DRIVE GRUB, then fix grub."
boot_to_target $TARGET_DRIVE "$REBOOT_HOSTS"                        || fail_exit "boot_to_target $TARGET_DRIVE \"$REBOOT_HOSTS\""


echo; echo "FIXING GRUB ON REBOOT_HOSTS: $REBOOT_HOSTS"
admin_control_fix_grub_these_hosts "$HOSTS"                         || fail_exit "admin_control_fix_grub_these_hosts \"$HOSTS\""
