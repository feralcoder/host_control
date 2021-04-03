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

# This script assumes the currently booted OS is the newly installed one to be set up.
# Also assumed is that the drive labels are already correct.  This can be overriden by args.

# There should be an admin USB key in the host to perform the label fixing and maybe sync keys from.

HOST=$1 DEVICE=$2 PREFIX=$3
# DEVICE: OPTIONAL, will be derived from currently booted system.
# PREFIX: OPTIONAL, will be derived from currently booted system.
SHORT_NAME=`group_logic_get_short_name $HOST`



fix_keys () {
  echo; echo "FIXING KEYS ON $HOST"
  ilo_control_refetch_ilo_hostkey_these_hosts $HOST
  ssh_control_refetch_hostkey_these_hosts $HOST

  echo; echo "SYNCING AUTH FROM ADMIN INSTALLATION on $HOST"
  echo "The next step may prompt for password, so I will wait until you type 'yes'."
  CONTINUE="wait"
  while [[ ${CONTINUE,,} != "yes" ]]; do
    read -p "Type 'yes' here: " CONTINUE
  done
  admin_control_sync_keys_from_admin $HOST

  ssh_control_refetch_hostkey_these_hosts $HOST
}



fix_boots () {
  # We should be booted to DEFAULT right now...
  echo; echo "FIXING HD GRUB (post-install, pre-label) ON $HOST HD INSTALL"
  admin_control_fix_grub $HOST

  [[ $DEVICE != "" ]] || DEVICE=`ssh_control_run_as_user root "mount" $HOST | grep ' / ' | awk '{print $1}' | sed 's/[0-9]*//g'`
  [[ $PREFIX != "" ]] || {
    BOOT_LINE=`ssh_control_run_as_user root "blkid" $HOST | grep $DEVICE | grep 'LABEL=".*_boot"'`
    PREFIX=`echo $BOOT_LINE | sed 's/.*LABEL="//g' | sed "s/${SHORT_NAME}_boot.*//g"`
  }

  echo; echo "BOOTING $HOST TO ADMIN TO RELABEL"
  os_control_boot_to_target_installation admin $HOST
  os_control_assert_hosts_booted_target admin $HOST || { echo "Failed to boot to admin!"; exit 1; }
  DEVICE=`ssh_control_run_as_user root "blkid" $HOST | grep ${PREFIX}${SHORT_NAME}_boot | awk '{print $1}' | sed 's/[0-9]:.*//g'`
  admin_control_fix_labels $DEVICE $PREFIX $HOST
  admin_control_fix_grub $HOST -1
  ilo_power_off $HOST
  ilo_power_wait_for_off $HOST

  echo; echo "BOOTING $HOST TO DEFAULT TO FIX GRUB"
  echo "The next step will boot to USB, hang, and you must select HD target.  Understand?"
  CONTINUE="wait"
  while [[ ${CONTINUE,,} != "yes" ]]; do
    read -p "Type 'yes' here: " CONTINUE
  done
  ilo_boot_target_once $DEV_USB $HOST
  ssh_control_wait_for_host_up $HOST
  os_control_assert_hosts_booted_target default $HOST || { echo "Failed to boot to default for grub fix on $HOST!"; exit 1; }

  admin_control_fix_grub $HOST
  ilo_power_off $HOST

  echo; echo "BOOTING $HOST TO ADMIN TO UNSET INFINITE GRUB"
  os_control_boot_to_target_installation admin $HOST
  os_control_assert_hosts_booted_target admin $HOST || { echo "Failed to boot to admin for grub fix on $HOST!"; exit 1; }
  admin_control_fix_grub $HOST

  echo; echo "REBOOTING $HOST TO DEFAULT"
  os_control_boot_to_target_installation default $HOST
  os_control_assert_hosts_booted_target default $HOST || { echo "Failed to boot to default on $HOST!"; exit 1; }
}





fix_keys
fix_boots


