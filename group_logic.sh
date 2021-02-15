#!/bin/bash -x

group_logic_intersection () {
  local GROUP_A=$1 GROUP_B=$2
  
  local ITEM
  INTERSECTION=$( for ITEM in $GROUP_A; do
    echo $GROUP_B | xargs -n1 echo | grep -e "^$ITEM$"
  done )
  echo $INTERSECTION
}

group_logic_in_list () {
  local ITEM=$1 LIST=$2
  local EACH_ITEM FOUND

  for EACH_ITEM in $LIST; do
    [[ $ITEM == $EACH_ITEM ]] && return 0
  done
  return 1
}

group_logic_exclusion () {
  local INGROUP=$1 OUTGROUP=$2
  
  local ITEM ONLY_INGROUP
  ONLY_INGROUP=$( for ITEM in $INGROUP; do
    ( group_logic_in_list $ITEM "$OUTGROUP" ) || echo $ITEM
  done )
  echo $ONLY_INGROUP
}

group_logic_get_all_ilo_names () {
  local HOST=$1
  local SHORT_HOSTNAME=`echo $HOST | awk -F'.' '{print $1}'`
  local ILO_IP=`getent hosts $SHORT_HOSTNAME-ipmi | awk '{print $1}' | tail -n 1`
  local ILO_NAMES=`grep "$ILO_IP " /etc/hosts | sed 's/^[^ ]*[ ]*//g'`
  echo $ILO_NAMES
}

group_logic_get_all_names () {
  local HOST=$1
  local HOST_IP=`getent hosts $HOST | awk '{print $1}' | tail -n 1`
  local HOST_NAMES=`grep "$HOST_IP " /etc/hosts | sed 's/^[^ ]*[ ]*//g'`
  echo $HOST_NAMES
}

