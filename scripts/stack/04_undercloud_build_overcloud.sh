#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

os_control_boot_to_target_installation default dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/train8 ; git pull" dmb

ssh_control_run_as_user root "rm /root/overcloud_install*; tmux new-session -d -s overcloud 'DEFOPTS=true /home/cliff/CODE/feralcoder/train8/setup_overcloud.sh > overcloud_install_\$\$.log'; sleep 5; tmux split-window -t overcloud -h 'tail -f /root/overcloud_install_*'" dmb



