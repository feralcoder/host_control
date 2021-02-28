#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

SRC_PREFIX=$1
DEST_PREFIX=$2
HOSTS=$3
[[ $HOSTS != "" ]] || {
  echo "No hosts provided.  Please call script with a host list to update."
  exit 1
}
#HOSTS="kgn neo bmn lmn mtn dmb"

# This script reboots all hosts to fix grub on the target disk.
# IOW: don't run this script from a target system.
# Yoda?  Yoda.

echo; echo "POWERING OFF $HOSTS"
ilo_power_off_these_hosts "$HOSTS"
echo; echo "BOOTING TO ADMIN ON $HOSTS"
os_control_boot_to_target_installation_these_hosts admin "$HOSTS"
os_control_assert_hosts_booted_target admin "$HOSTS" || {
  echo "Not all hosts booted to admin OS, check the environment!"
  return 1
}
echo; echo "ALL HOSTS ARE BOOTED TO ADMIN"
echo; echo "CLONING DRIVES $SRC_PREFIX TO $DEST_PREFIX on $HOSTS, THEN FIXING LABELS"
admin_control_clone_and_fix_labels_these_hosts $SRC_PREFIX $DEST_PREFIX "$HOSTS" 
echo; echo "FIXING GRUB ON ADMIN STICKS FOR $HOSTS"
admin_control_fix_grub_these_hosts "$HOSTS" -1

echo; echo "POWERING OFF BEFORE BOOTING TO NEW DUMPS ON $HOSTS"
ilo_power_off_these_hosts "$HOSTS"

echo; echo "WAITING FOR HOSTS TO POWER OFF"
ssh_control_wait_for_host_down_these_hosts "$HOSTS"
echo; echo "HOSTS POWERED OFF: $HOSTS"



CONTINUE="wait"
echo "The next step is to boot into the newly dumped drive.  The only updated grub is this one, on admin."
echo "We're about to boot to the admin stick.  It's your job to catch each machine in grub and pick the newly dumped disk."
echo "Nod if you understand.  And type 'yes'."
echo "And then hit enter."
while [[ ${CONTINUE,,} != "yes" ]]; do
  read -p "Type 'yes' here: " CONTINUE
done

ERROR_COUNT=0
echo; echo "BOOTING HOSTS FROM USB STICK: $HOSTS"
ilo_boot_target_once_these_hosts $DEV_USB "$HOSTS"
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

echo; echo "POWERING OFF $HOSTS BEFORE BOOTING TO ADMIN OS"
ilo_power_off_these_hosts "$HOSTS"
echo; echo "BOOTING TO ADMIN ON $HOSTS"
os_control_boot_to_target_installation_these_hosts admin "$HOSTS"
os_control_assert_hosts_booted_target admin "$HOSTS" || {
  echo "Not all hosts booted to admin OS, check the environment!"
  return 1
}

echo; echo "ALL HOSTS ARE BOOTED TO ADMIN"
echo; echo "FIXING GRUB AGAIN TO FIX TIMEOUT (infinite --> 30s)"
admin_control_fix_grub_these_hosts "$HOSTS"
echo; echo "ALL UPDATES FINISHED!"
