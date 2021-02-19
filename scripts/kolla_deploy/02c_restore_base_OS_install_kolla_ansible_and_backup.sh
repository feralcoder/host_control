#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../../control_scripts.sh

UPDATED_OS_LINK=$1
[[ $UPDATED_OS_LINK == "" ]] && {
  UPDATED_OS_LINK=dumbledoreB_01_CentOS_8_2_Updated
}

BUILD_OPTIONS=$2
[[ $BUILD_OPTIONS == "" ]] && {
  BUILD_OPTIONS="DEFOPTS=true"
}

BUILT_KOLLA_LINK=$3
[[ $BUILT_KOLLA_LINK == "" ]] && {
  BUILT_KOLLA_LINK=dumbledoreB_02_Kolla_Ansible
}

. $THIS_SOURCE/01a_restore_base_OS.sh $UPDATED_OS_LINK
. $THIS_SOURCE/01e_install_kolla_ansible.sh "$BUILD_OPTIONS"
. $THIS_SOURCE/01f_backup_kolla_ansible.sh $BUILT_KOLLA_LINK
