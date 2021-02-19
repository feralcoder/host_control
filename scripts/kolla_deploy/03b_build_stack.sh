#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

BUILD_OPTIONS=$1
[[ $BUILD_OPTIONS == "" ]] && {
  BUILD_OPTIONS="DEFOPTS=true"
}


os_control_boot_to_target_installation default dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/ansible-kolla ; git pull" dmb

ssh_control_run_as_user root "rm /root/kolla_install*; tmux new-session -d -s kolla '$BUILD_OPTIONS /home/cliff/CODE/feralcoder/ansible-kolla/setup.sh > kolla_install_\$\$.log'; sleep 5; tmux split-window -t kolla -h 'tail -f /root/kolla_install_*'" dmb
