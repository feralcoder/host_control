#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

os_control_boot_to_target_installation default dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/host_control ; git pull" dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/workstation ; git pull" dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/bootstrap-scripts ; git pull" dmb
ssh_control_run_as_user cliff "cd ~cliff/CODE/feralcoder/kolla-ansible ; git pull" dmb
ssh_control_run_as_user root "dnf upgrade -y" dmb
