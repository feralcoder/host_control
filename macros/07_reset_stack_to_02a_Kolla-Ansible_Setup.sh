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

$MACRO_DIR/09_reset_everything.sh 02a_Kolla-Ansible_Setup a "$STACK_HOSTS"



echo; echo "BOOTING TO DEFAULT OS ON $STACK_HOSTS"
os_control_boot_to_target_installation_these_hosts default "$STACK_HOSTS"
os_control_assert_hosts_booted_target default "$STACK_HOSTS" || {
  echo "Not all hosts booted to default OS, check the environment!"
  exit 1
}
echo; echo "ALL HOSTS ARE BOOTED TO default"
