#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh


os_control_boot_to_target_installation admin dmb

undercloud_control_backup_dumbledore dumbledoreB_02_Ussuri_Undercloud_HA_NoVlans
# os_control_boot_to_target_installation default dmb
# ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/train8 ; git pull" dmb

# ssh_control_run_as_user root "rm /root/undercloud_install*; tmux new-session -d -s undercloud 'DEFOPTS=true /home/cliff/CODE/feralcoder/train8/setup_undercloud.sh > undercloud_install_\$\$.log'; tmux split-window -t undercloud -h 'tail -f /root/undercloud_install_\$\$'" dmb



