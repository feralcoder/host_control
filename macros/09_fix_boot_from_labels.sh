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

FIX_PREFIX=$1
HOSTS=$2
[[ $HOSTS != "" ]] || {
  echo "No hosts provided.  Please call script with a host list to update."
  exit 1
}

# This script assumes an xyyy_root labeling scheme, where
#  x=a|b|c...
#  yyy=short_hostname
# If this doesn't describe your disk, relabel first, then run this.

# This script reboots all hosts to fix grub on the target disk.
# IOW: don't run this script from a target system.
# Yoda?  Yoda.

echo; echo "POWERING OFF $HOSTS"
ilo_power_off_these_hosts "$HOSTS"
[[ $FIX_PREFIX == x ]] && {
  OPERATING_DRIVE=default
  TARGET_DRIVE=admin
  OPERATING_BOOT_DEV=$DEV_HD
} || {
  OPERATING_DRIVE=admin
  TARGET_DRIVE=default
  OPERATING_BOOT_DEV=$DEV_USB
}

echo; echo "BOOTING TO $OPERATING_DRIVE ON $HOSTS"
os_control_boot_to_target_installation_these_hosts $OPERATING_DRIVE "$HOSTS"
os_control_assert_hosts_booted_target $OPERATING_DRIVE "$HOSTS" || {
  echo "Not all hosts booted to $OPERATING_DRIVE OS, check the environment!"
  exit 1
}
echo; echo "ALL HOSTS ARE BOOTED TO $OPERATING_DRIVE"


echo; echo "FIXING $FIX_PREFIX LABELED SYSTEMS on $HOSTS"
admin_control_fix_labels_from_prefix_these_hosts "$HOSTS"
echo; echo "FIXING GRUB ON ADJACENT DRIVE FOR $HOSTS"
admin_control_fix_grub_these_hosts "$HOSTS" -1

echo; echo "POWERING OFF BEFORE BOOTING TO NEW FIXED DRIVES ON $HOSTS"
ilo_power_off_these_hosts "$HOSTS"
echo; echo "WAITING FOR HOSTS TO POWER OFF"
ssh_control_wait_for_host_down_these_hosts "$HOSTS"
echo; echo "HOSTS POWERED OFF: $HOSTS"


CONTINUE="wait"
echo "The next step is to boot into the newly fixed drive.  The only updated grub is this one, the $OPERATING_DRIVE OS."
echo "We're about to boot to the $OPERATING_DRIVE DRIVE.  It's your job to catch each machine in grub and pick the $TARGET_DRIVE OS."
echo "Nod if you understand.  And type 'yes'."
echo "And then hit enter."
while [[ ${CONTINUE,,} != "yes" ]]; do
  read -p "Type 'yes' here: " CONTINUE
done

ERROR_COUNT=0
echo; echo "BOOTING HOSTS FROM $OPERATING_DRIVE $HOSTS"
ilo_boot_target_once_these_hosts $OPERATING_BOOT_DEV "$HOSTS"
echo; echo "WAITING FOR HOSTS TO COME UP: $HOSTS"
ssh_control_wait_for_host_up_these_hosts "$HOSTS"
ERROR_COUNT=$?
if [[ $ERROR_COUNT -gt 0 ]]; then
  echo "$ERROR_COUNT hosts did not come up!"
  echo "Waiting some more..."
  ssh_control_wait_for_host_up_these_hosts "$HOSTS"
  ERROR_COUNT=$?
  if [[ $ERROR_COUNT -gt 0 ]]; then
    echo "$ERROR_COUNT hosts are still not up!"
    echo "EXITING!"
    exit 1
  fi
fi
echo; echo "ALL HOSTS ARE UP: $HOSTS"

echo; echo "FIXING GRUB ON NEW DUMPS ON $HOSTS"
admin_control_fix_grub_these_hosts "$HOSTS"

echo; echo "POWERING OFF $HOSTS BEFORE BOOTING TO $OPERATING_DRIVE OS"
ilo_power_off_these_hosts "$HOSTS"
echo; echo "BOOTING TO $OPERATING_DRIVE ON $HOSTS"
os_control_boot_to_target_installation_these_hosts $OPERATING_DRIVE "$HOSTS"
os_control_assert_hosts_booted_target $OPERATING_DRIVE "$HOSTS" || {
  echo "Not all hosts booted to $OPERATING_DRIVE OS, check the environment!"
  exit 1
}

echo; echo "ALL HOSTS ARE BOOTED TO $OPERATING_DRIVE"
echo; echo "FIXING GRUB AGAIN TO FIX TIMEOUT (infinite --> 30s)"
admin_control_fix_grub_these_hosts "$HOSTS"
echo; echo "ALL UPDATES FINISHED!"
