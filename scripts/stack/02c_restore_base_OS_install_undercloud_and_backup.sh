#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

UPDATED_OS_LINK=$1
[[ $UPDATED_OS_LINK == "" ]] && {
  UPDATED_OS_LINK=dumbledoreB_01_CentOS_8_2_Updated
}

UNDERCLOUD_BUILD_OPTIONS=$2
[[ $UNDERCLOUD_BUILD_OPTIONS == "" ]] && {
  UNDERCLOUD_BUILD_OPTIONS="DEFOPTS=true"
}

BUILT_UNDERCLOUD_LINK=$3
[[ $BUILT_UNDERCLOUD_LINK == "" ]] && {
  BUILT_UNDERCLOUD_LINK=dumbledoreB_02_Ussuri_Undercloud_HA_NoVlans
}

. $THIS_SOURCE/01a_restore_base_OS.sh $UPDATED_OS_LINK
. $THIS_SOURCE/01e_install_undercloud.sh "$UNDERCLOUD_BUILD_OPTIONS"
. $THIS_SOURCE/01f_backup_undercloud.sh $BUILT_UNDERCLOUD_LINK
