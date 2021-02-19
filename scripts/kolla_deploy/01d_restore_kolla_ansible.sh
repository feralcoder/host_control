#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

BUILT_KOLLA_LINK=$1
[[ $BUILT_KOLLA_LINK == "" ]] && {
  BUILT_KOLLA_LINK=dumbledoreB_02_Kolla_Ansible
}

os_control_boot_to_target_installation admin dmb
stack_control_restore_dumbledore $BUILT_KOLLA_LINK
