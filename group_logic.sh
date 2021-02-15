#!/bin/bash -x

group_logic_intersection () {
  local GROUP_A=$1 GROUP_B=$2
  
  local ITEM
  INTERSECTION=$( for ITEM in $GROUP_A; do
    echo $GROUP_B | xargs -n1 echo | grep -e "^$ITEM$"
  done )
  echo $INTERSECTION
}
