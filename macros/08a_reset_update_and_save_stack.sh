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

#RESTORE_FROM=01_CentOS_8_3_Admin_Install_REBUILT
RESTORE_FROM=01b_CentOS_8_3_Admin_Install_REBUILT
#RESTORE_FROM=01c_CentOS_8_3_Remediated
#RESTORE_FROM=01d_CentOS_8_3_Postmediated
#RESTORE_FROM=02a_Kolla-Ansible_Setup
#RESTORE_FROM=02b_Ceph_Setup

#BACKUP_TO=01_CentOS_8_3_Admin_Install_REBUILT
#BACKUP_TO=01b_CentOS_8_3_Admin_Install_REBUILT
BACKUP_TO=01c_CentOS_8_3_Remediated
#BACKUP_TO=01d_CentOS_8_3_Postmediated
#BACKUP_TO=02a_Kolla-Ansible_Setup
#BACKUP_TO=02b_Ceph_Setup





remediate_access () {
# root users also need to know all hosts, for backup rsyncs
  for HOST in $STACK_HOSTS; do
    ssh_control_run_as_user root ". ~cliff/CODE/feralcoder/host_control/control_scripts.sh; ssh_control_refetch_hostkey_these_hosts \"$HOSTS\"" $HOST                  || return 1
  done

  ROOT_PUBS=/tmp/root_pubs_$$
  ssh_control_run_as_user_these_hosts root "[[ -f ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa" "$ALL_HOSTS"                                         || return 1
  ssh_control_run_as_user_these_hosts root "cat ~/.ssh/id_rsa.pub" "$STACK_HOSTS" | grep '^ssh' > $ROOT_PUBS                                                           || return 1
  ssh_control_sync_as_user_these_hosts root $ROOT_PUBS $ROOT_PUBS "$STACK_HOSTS"                                                                                       || return 1
  ssh_control_run_as_user_these_hosts root "cat ~/.ssh/authorized_keys $ROOT_PUBS | sort | uniq > ${ROOT_PUBS}x ; cat ${ROOT_PUBS}x > ~/.ssh/authorized_keys" "$HOSTS" || return 1
}

remediate () {
  # Admin and Pager
  ssh_control_run_as_user_these_hosts cliff "cd ~/CODE/feralcoder/workstation && git pull" "$ALL_HOSTS"
  ssh_control_run_as_user_these_hosts cliff "~/CODE/feralcoder/workstation/update.sh" "$ALL_HOSTS" || return 1
  ssh_control_run_as_user_these_hosts cliff "python3 $TWILIO_PAGER_DIR/pager.py \"hello from \`hostname\`\"" "$STACK_HOSTS"
  
  # Performance Tools
  ssh_control_run_as_user_these_hosts cliff "( grep 'PATH.*share.bcc.tools' .bash_profile ) && sed -i 's|.*PATH.*share.bcc.tools.*|export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools|g' .bash_profile || echo 'export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools' >> ~/.bash_profile" "$STACK_HOSTS"
  ssh_control_run_as_user_these_hosts root "( grep 'PATH.*share.bcc.tools' .bash_profile ) && sed -i 's|.*PATH.*share.bcc.tools.*|export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools|g' .bash_profile || echo 'export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools' >> ~/.bash_profile" "$STACK_HOSTS"

  # Setup Dumbledore as Stack Controller
  ssh_control_run_as_user cliff "rm .local_settings && cd ~/CODE/feralcoder/bootstrap-scripts && ./stack_control.sh" $ANSIBLE_CONTROLLER
}

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

remediate_access                                                  || fail_exit "remediate_access"
remediate                                                         || fail_exit "remediate"

$MACRO_DIR/02a_hosts_update.sh "$STACK_HOSTS"                     || fail_exit "02a_hosts_update.sh \"$STACK_HOSTS\""
$MACRO_DIR/09_backup_everything.sh $BACKUP_TO a "$STACK_HOSTS"    || fail_exit "09_backup_everything.sh $BACKUP_TO a \"$STACK_HOSTS\""

echo; echo "BOOTING TO DEFAULT OS ON $STACK_HOSTS"
boot_to_target default                                            || fail_exit "boot_to_target default"
echo; echo "ALL HOSTS ARE BOOTED TO default"
