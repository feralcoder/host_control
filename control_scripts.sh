#!/bin/bash -x
CONTROL_SOURCE="${BASH_SOURCE[0]}"
CONTROL_DIR=$( dirname $CONTROL_SOURCE )

# Run only this file to include the others:
. $CONTROL_DIR/wiki_control.sh
. $CONTROL_DIR/group_logic.sh
. $CONTROL_DIR/ilo_common.sh
. $CONTROL_DIR/ilo_control.sh
. $CONTROL_DIR/ilo_power.sh
. $CONTROL_DIR/ilo_boot.sh
. $CONTROL_DIR/ilo_boot_target.sh

. $CONTROL_DIR/git_control.sh
. $CONTROL_DIR/ssh_control.sh
. $CONTROL_DIR/os_control.sh
. $CONTROL_DIR/backup_control.sh
. $CONTROL_DIR/admin_control.sh
. $CONTROL_DIR/kolla_control.sh
. $CONTROL_DIR/tripleo_control.sh

ILO2_HOSTS="mrl gnd yda dmb"
ILO4_HOSTS="mtn lmn bmn neo str kgn"

PRIMARY_CONTROL_HOSTS="str"
SECONDARY_CONTROL_HOSTS="mrl"
TERNARY_CONTROL_HOSTS="gnd"
CONTROL_HOSTS="$PRIMARY_CONTROL_HOSTS $SECONDARY_CONTROL_HOSTS $TERNARY_CONTROL_HOSTS"

COMPUTE_HOSTS="mtn lmn bmn neo kgn"
OSD_HOSTS="mtn lmn bmn neo kgn"
COMPUTE_HCI_HOSTS=`group_logic_intersection "$COMPUTE_HOSTS" "OSD_HOSTS"`

OVERCLOUD_HOSTS="mtn lmn bmn neo mrl gnd str kgn"

UNDERCLOUD_HOSTS="dmb"
KOLLA_HOSTS="$UNDERCLOUD_HOSTS"

CLOUD_HOSTS=`group_logic_union "$CONTROL_HOSTS" "$COMPUTE_HOSTS"`
STACK_HOSTS=`group_logic_union "$CLOUD_HOSTS" "$KOLLA_HOSTS"`

ALL_HOSTS="mtn lmn bmn kgn neo str mrl gnd yda dmb"
ADMIN_HOSTS="yda"
ALL_HOSTS_MINUS_ADMIN=`group_logic_exclusion "$ALL_HOSTS" "$ADMIN_HOSTS"`

ALL_HOSTS_LONGNAMES="manhattan lawnmowerman bowman kerrigan neo strange merlin gandalf yoda dumbledore"
ALL_HOSTS_API_NET="manhattan-api lawnmowerman-api bowman-api kerrigan-api neo-api strange-api merlin-api gandalf-api yoda-api dumbledore-api"
STACK_HOSTS_API_NET="manhattan-api lawnmowerman-api bowman-api kerrigan-api neo-api strange-api merlin-api gandalf-api dumbledore-api"
