#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

# This script assumes the newly installed admin key is labeled with '*xax*'-type labels.
# If multiple matching devices are found, the script will require explicit targeting.


HOST=$1 DEVICE=$2
# DEVICE: OPTIONAL, will be derived from blkid
SHORT_NAME=`group_logic_get_short_name $HOST`
[[ $PREFIX != "" ]] || {
  BOOT_LINE=`ssh_control_run_as_user root "blkid" $HOST | grep $DEVICE | grep 'LABEL=".*_boot"'`
  PREFIX=`echo $BOOT_LINE | sed 's/.*LABEL="//g' | sed "s/${SHORT_NAME}_boot.*//g"`
}

UNQUALIFIED_NAME=`ssh_control_run_as_user root "hostname" $HOST | grep feralcoder.org | awk -F'.' '{print $1}'`
LONGNAME=`echo $UNQUALIFIED_NAME | awk -F'-' '{print $1}'`


[[ $DEVICE != "" ]] && {
  echo "ADMIN STICK $DEVICE WILL BE USED"
} || {
  echo; echo "PROBING $HOST FOR ADMIN STICK"
  PARTLINES=`ssh_control_run_as_user root "blkid | grep 'LABEL=\"[a-z]*xax'" $HOST | grep LABEL`
  DEVS=`echo "$PARTLINES" | awk '{print $1}' | sed 's/[0-9]*://g' | sort | uniq`
  NULL_IF_SPACES_DETECTED=`echo $DEVS | sed 's/.* .*//g'`
  [[ $NULL_IF_SPACES_DETECTED != "" ]] || {
    echo "Multiple admin sticks detected in $HOST!"
    echo "Please remove extras, or explicitly provide $DEVICE argument!"
    exit 1
  }
}


echo; echo "FIXING LABELS ON $HOST ADMIN STICK"
admin_control_fix_labels $DEVICE x $HOST
admin_control_fix_admin_key $DEVICE $LONGNAME


echo; echo "FIXING KEYS ON $HOST ADMIN STICK"
admin_control_sync_keys_to_admin $HOST

echo; echo "FIXING GRUB ON $HOST"
admin_control_fix_grub $HOST -1

echo; echo "BOOTING TO HD GRUB, CHOOSE x$SHORT_NAME!"
ilo_power_cycle $HOST
ssh_control_wait_for_host_up $HOST
if [[ $? -gt 0 ]]; then
  echo "Host $HOST did not come up!"
  echo "Waiting some more..."
  ssh_control_wait_for_host_up_these_hosts "$HOSTS"
  if [[ $? -gt 0 ]]; then
    echo "Host $HOST did not come up!"
    echo "EXITING!"
    exit 1
  fi
fi
echo; echo "$HOST IS UP."

os_control_assert_hosts_booted_target admin $HOST || { echo "Failed to boot to admin!"; exit 1; }
admin_control_make_no_crossboot $HOST
admin_control_fix_grub_os_prober $HOST
admin_control_fix_grub $HOST

echo; echo "BOOTING $HOST BACK TO DEFAULT OS"
os_control_boot_to_target_installation default $HOST
os_control_assert_hosts_booted_target default $HOST || { echo "Failed to boot to default!"; exit 1; }

echo; echo "FIXING GRUB ON $HOST"
admin_control_fix_grub $HOST
