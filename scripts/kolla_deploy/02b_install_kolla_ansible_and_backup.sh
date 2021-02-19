#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

BUILD_OPTIONS=$1
[[ $BUILD_OPTIONS == "" ]] && {
  BUILD_OPTIONS="DEFOPTS=true"
}

BUILT_KOLLA_LINK=$2
[[ $BUILT_KOLLA_LINK == "" ]] && {
  BUILT_KOLLA_LINK=dumbledoreB_02_Kolla_Ansible
}

os_control_boot_to_target_installation default dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/kolla-ansible ; git pull" dmb

ssh_control_run_as_user root "rm /root/kolla_install*; tmux new-session -d -s kolla '$BUILD_OPTIONS /home/cliff/CODE/feralcoder/kolla-ansible/setup.sh > kolla_install_\$\$.log'; tmux split-window -t kolla -h 'tail -f /root/kolla_install_\$\$'" dmb

os_control_boot_to_target_installation admin dmb
stack_control_backup_dumbledore $BUILT_KOLLA_LINK

