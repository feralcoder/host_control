#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

UNDERCLOUD_BUILD_OPTIONS=$1
[[ $UNDERCLOUD_BUILD_OPTIONS == "" ]] && {
  UNDERCLOUD_BUILD_OPTIONS="DEFOPTS=true"
}

os_control_boot_to_target_installation default dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/train8 ; git pull" dmb

ssh_control_run_as_user root "rm /root/undercloud_install*; tmux new-session -d -s undercloud '$UNDERCLOUD_BUILD_OPTIONS /home/cliff/CODE/feralcoder/train8/setup_undercloud.sh > undercloud_install_\$\$.log'; tmux split-window -t undercloud -h 'tail -f /root/undercloud_install_\$\$'" dmb
