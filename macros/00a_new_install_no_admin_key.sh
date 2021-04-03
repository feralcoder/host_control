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
# This process assumes these newly created host keys are permanent, and need to be distributed.
# Also assumed is that the admin key will be installed later and will take the keys set up here.

HOST=$1 HOSTS=$2
[[ $HOSTS != "" ]] || HOSTS="$ALL_HOSTS"

echo; echo "FIXING KEYS ON $HOST"
ilo_control_refetch_ilo_hostkey_these_hosts $HOST
ssh_control_refetch_hostkey_these_hosts $HOST

echo; echo "DISTRIBUTING $HOST's KEYS ACROSS $HOSTS"
# Serialize this, to not overload ILO port.
for TARGET in $HOSTS; do
  ssh_control_run_as_user cliff "ssh_control_refetch_ilo_hostkey_these_hosts $HOST" $TARGET
done
ssh_control_run_as_user_these_hosts cliff "ssh_control_refetch_ilo_hostkey_these_hosts $HOSTS"

echo; echo "FIXING GRUB ON $HOST"
admin_control_make_no_crossboot $HOST
admin_control_fix_grub_os_prober $HOST
admin_control_fix_grub $HOST
admin_control_fix_mounts $HOST
