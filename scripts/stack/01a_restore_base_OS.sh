#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

UPDATED_OS_LINK=$1

[[ $UPDATED_OS_LINK == "" ]] && {
  UPDATED_OS_LINK=dumbledoreB_01_CentOS_8_2_Updated
}


os_control_boot_to_target_installation admin dmb
undercloud_control_restore_dumbledore $UPDATED_OS_LINK
