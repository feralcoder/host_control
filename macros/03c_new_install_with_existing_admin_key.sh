#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

# This script assumes the currently booted OS is the newly installed one to be set up.
# Also assumed is that the drive labels are already correct.  This can be overriden by args.

# There should be an admin USB key in the host to perform the label fixing and maybe sync keys from.

HOST=$1 DEVICE=$2 PREFIX=$3
# DEVICE: OPTIONAL, will be derived from currently booted system.
# PREFIX: OPTIONAL, will be derived from currently booted system.
SHORT_NAME=`group_logic_get_short_name $HOST`
[[ $DEVICE != "" ]] || DEVICE=`ssh_control_run_as_user root "mount" $HOST | grep ' / ' | awk '{print $1}' | sed 's/[0-9]*//g'`
[[ $PREFIX != "" ]] || {
  BOOT_LINE=`ssh_control_run_as_user root "blkid" $HOST | grep $DEVICE | grep 'LABEL=".*_boot"'`
  PREFIX=`echo $BOOT_LINE | sed 's/.*LABEL="//g' | sed "s/${SHORT_NAME}_boot.*//g"`
}

echo; echo "FIXING KEYS ON $HOST"
ilo_control_refetch_ilo_hostkey_these_hosts $HOST
ssh_control_refetch_hostkey_these_hosts $HOST
admin_control_sync_keys_from_admin $HOST
ssh_control_refetch_hostkey_these_hosts $HOST

echo; echo; "FIXING GRUB ON $HOST"
admin_control_make_no_crossboot $HOST
admin_control_fix_grub_os_prober $HOST
admin_control_fix_grub $HOST

echo; echo; "BOOTING $HOST TO ADMIN TO RELABEL"
os_control_boot_to_target_installation admin $HOST
os_control_assert_hosts_booted_target admin $HOST || { echo "Failed to boot to admin!"; return 1; }
admin_control_fix_labels $DEVICE $PREFIX $HOST
admin_control_fix_grub $HOST
os_control_boot_to_target_installation default $HOST
os_control_assert_hosts_booted_target default $HOST || { echo "Failed to boot to default!"; return 1; }
