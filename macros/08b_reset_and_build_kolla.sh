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

KOLLA_ADMIN_DIR=~/CODE/feralcoder/kolla-ansible/admin-scripts/

#RESTORE_FROM=01_CentOS_8_3_Admin_Install
RESTORE_FROM=01b_CentOS_8_3_Admin_Install
#RESTORE_FROM=02a_Kolla-Ansible_Setup
#RESTORE_FROM=02b_Ceph_Setup

fail_exit () {
  echo; echo "INSTALLATION FAILED AT STEP: $1"
  echo "Check the logs and try again.  Or just give up.  I don't care."
  python3 ~/CODE/feralcoder/twilio-pager/pager.py "Fallen.  Can't get up.  Installation failed at $1."
  exit 1
}


boot_to_target () {
  local TARGET=$1
  [[ $TARGET == "admin" ]] || [[ $TARGET == "default" ]] || { echo "boot_to_target - target must be 'admin' or 'default'!"; return 1; }

  # Boot all hosts to default / admin
  os_control_boot_to_target_installation_these_hosts $TARGET "$STACK_HOSTS" || return 1
  ssh_control_wait_for_host_up_these_hosts "$STACK_HOSTS" || return 1
  os_control_assert_hosts_booted_target $TARGET "$STACK_HOSTS" || {
    echo "All stack hosts must be in their $TARGET OS to install the stack!"
    exit 1
  }
}



$MACRO_DIR/09_reset_everything.sh $RESTORE_FROM a "$STACK_HOSTS"  || fail_exit "09_reset_everything.sh $RESTORE_FROM a \"$STACK_HOSTS\""

echo; echo "BOOTING TO DEFAULT OS ON $STACK_HOSTS"
boot_to_target default                                            || fail_exit "boot_to_target default"
echo; echo "ALL HOSTS ARE BOOTED TO default"

$KOLLA_ADMIN_DIR/macro-management/02a_setup_kolla_and_install.sh  || fail_exit "02a_setup_kolla_and_install.sh"
