#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

os_control_boot_to_target_installation admin dmb
undercloud_control_restore_dumbledore dumbledoreB_02_Ussuri_Undercloud_HA_NoVlans
os_control_boot_to_target_installation default dmb
