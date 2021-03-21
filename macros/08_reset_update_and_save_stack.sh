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

RESTORE_FROM=01_CentOS_8_3_Admin_Install
#RESTORE_FROM=01b_CentOS_8_3_Admin_Install
#RESTORE_FROM=02a_Kolla-Ansible_Setup
#RESTORE_FROM=02b_Ceph_Setup

BACKUP_TO=01b_CentOS_8_3_Admin_Install
#BACKUP_TO=02a_Kolla-Ansible_Setup
#BACKUP_TO=02b_Ceph_Setup


remediate () {
# root users also need to know all hosts, for backup rsyncs
  for HOST in $STACK_HOSTS; do
    ssh_control_run_as_user root ". ~cliff/CODE/feralcoder/host_control/control_scripts.sh; ssh_control_refetch_hostkey_these_hosts \"$HOSTS\"" $HOST
  done
  
  $ROOT_PUBS=/tmp/root_pubs_$$
  ssh_control_run_as_user_these_hosts root "[[ -f ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa" "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts root "cat ~/.ssh/id_rsa.pub" "$STACK_HOSTS" | grep '^ssh' > $ROOT_PUBS
  ssh_control_sync_as_user_these_hosts root $ROOT_PUBS $ROOT_PUBS "$STACK_HOSTS"
  ssh_control_run_as_user_these_hosts root "cat ~/.ssh/authorized_keys $ROOT_PUBS | sort | uniq > ${ROOT_PUBS}x ; cat ${ROOT_PUBS}x > ~/.ssh/authorized_keys" "$HOSTS"
}


boot_to_target () {
  local TARGET=$1
  [[ $TARGET == "admin" ]] || [[ $TARGET == "default" ]] || fail_exit "boot_to_target - target must be 'admin' or 'default'!"

  # Boot all hosts to default / admin
  os_control_boot_to_target_installation_these_hosts $TARGET "$STACK_HOSTS" || exit 1
  ssh_control_wait_for_host_up_these_hosts "$STACK_HOSTS" || exit 1
  os_control_assert_hosts_booted_target $TARGET "$STACK_HOSTS" || {
    echo "All stack hosts must be in their $TARGET OS to install the stack!"
    exit 1
  }
}



$MACRO_DIR/09_reset_everything.sh $RESTORE_FROM a "$STACK_HOSTS"

echo; echo "BOOTING TO DEFAULT OS ON $STACK_HOSTS"
boot_to_target default || exit 1
echo; echo "ALL HOSTS ARE BOOTED TO default"

remediate

$MACRO_DIR/02a_hosts_update.sh "$STACK_HOSTS"
$MACRO_DIR/09_backup_everything.sh $BACKUP_TO a "$STACK_HOSTS"

echo; echo "BOOTING TO DEFAULT OS ON $STACK_HOSTS"
boot_to_target default || exit 1
echo; echo "ALL HOSTS ARE BOOTED TO default"
