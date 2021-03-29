#!/bin/bash -x

# Returns 3-character hostname; Translates *-api names to base names.
group_logic_get_short_name () {
  HOST=$1
  HOST=`echo $HOST | sed 's/-api//g'`
  local NAMES=`group_logic_get_all_names $HOST`
  local SHORT_NAME=`echo $NAMES | tr ' '  '\n' | grep -E '^[a-z]{3,3}$' | tail -n 1`
  echo $SHORT_NAME
}

group_logic_union () {
  local GROUP INTERSECTION="" UNION=""

  ARRAY_ARRAY=("$@")

  for i in `seq 0 "${#ARRAY_ARRAY[@]}"` now_done; do
    if [[ $i == "${#ARRAY_ARRAY[@]}" ]]; then
      echo $UNION
    else
      GROUP=${ARRAY_ARRAY[$i]}
      INTERSECTION=`group_logic_intersection "$UNION" "$GROUP"`
      EXCLUSION_1=`group_logic_exclusion "$UNION" "$GROUP"`
      EXCLUSION_2=`group_logic_exclusion "$GROUP" "$UNION"`
      UNION="$INTERSECTION $EXCLUSION_1 $EXCLUSION_2"
    fi
  done
}

group_logic_intersection () {
  local GROUP_A=$1 GROUP_B=$2

  local ITEM
  INTERSECTION=$( for ITEM in $GROUP_A; do
    echo $GROUP_B | xargs -n1 echo | grep -e "^$ITEM$"
  done )
  echo $INTERSECTION
}

group_logic_exclusion () {
  local INGROUP=$1 OUTGROUP=$2

  local ITEM ONLY_INGROUP
  ONLY_INGROUP=$( for ITEM in $INGROUP; do
    ( group_logic_in_list $ITEM "$OUTGROUP" ) || echo $ITEM
  done )
  echo $ONLY_INGROUP
}

group_logic_in_list () {
  local ITEM=$1 LIST=$2

  local EACH_ITEM FOUND
  for EACH_ITEM in $LIST; do
    [[ $ITEM == $EACH_ITEM ]] && return 0
  done
  return 1
}

group_logic_get_all_ilo_names () {
  local HOST=$1
  local SHORT_HOSTNAME=`echo $HOST | awk -F'.' '{print $1}'`
  local ILO_IP=`getent ahosts $SHORT_HOSTNAME-ipmi | awk '{print $1}' | tail -n 1`
  local ILO_NAMES=`grep "$ILO_IP " /etc/hosts | sed 's/^[^ ]*[ ]*//g'`
  echo $ILO_NAMES
}

group_logic_get_all_names () {
  local HOST=$1
  local HOST_IP=`getent ahosts $HOST | awk '{print $1}' | tail -n 1`
  local HOST_NAMES=`grep "$HOST_IP " /etc/hosts | sed 's/^[^ ]*[ ]*//g'`
  echo $HOST_NAMES
}

group_logic_remove_self () {
  local HOSTS=$1
  if [[ $( group_logic_intersection "`group_logic_get_all_names $(hostname)`" "$HOSTS" ) != "" ]] ; then
    echo "SELF DETECTED in $HOSTS!" 1>&2
    echo "Not running in UNSAFE mode, removing self." 1>&2
    HOSTS=$(group_logic_exclusion "$ALL_HOSTS"  "`group_logic_get_all_names $(hostname)`")
    echo "New hosts list: $HOSTS" 1>&2
    echo "$HOSTS"
    return
  fi
  echo "$HOSTS"
}
