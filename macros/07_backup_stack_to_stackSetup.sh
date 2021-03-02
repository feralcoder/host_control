#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

. ~/CODE/feralcoder/host_control/control_scripts.sh

$MACRO_DIR/09_backup_everything.sh 02_Stack_Setup a "$STACK_HOSTS"




echo; echo "BOOTING TO DEFAULT OS ON $HOSTS"
os_control_boot_to_target_installation_these_hosts default "$HOSTS"
os_control_assert_hosts_booted_target default "$HOSTS" || {
  echo "Not all hosts booted to default OS, check the environment!"
  exit 1
}
echo; echo "ALL HOSTS ARE BOOTED TO default"
