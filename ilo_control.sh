#!/bin/bash

ilo_control_get_all_names () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  local ILO_NAMES=`grep "$ILO_IP " /etc/hosts | sed 's/^[^ ]*[ ]*//g'`
  echo $ILO_NAMES
}

ilo_control_get_hw_gen () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  local GENERATION

  local i COUNT=60 INTERVAL=10
  for i in `seq 1 $COUNT`; do
    GENERATION=`ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "show system1 name" | grep "name=" | tr '\r' ' ' | awk -F'=' '{print $2}' | awk '{print $3}'`
    [[ $? == "0" ]] && {
      if [[ $GENERATION == G6 ]]; then
        echo 6; return 0
      elif [[ $GENERATION == Gen8 ]]; then
        echo 8; return 0
      fi
    } || {
      echo "Problem getting hw generation info on $HOST!" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
  return 1
}

ilo_control_remove_ilo_hostkey () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  local ALL_NAMES=`ilo_control_get_all_names $HOST`
  local NAME
  touch ~/.ssh/known_hosts
  for NAME in $ALL_NAMES; do
    ssh-keygen -R $NAME
  done
  ssh-keygen -R $ILO_IP
}

ilo_control_get_ilo_hostkey () {
  # TAKES SHORT HOSTNAME - NOT ILO NAMES!
  # If you have ilo names, use ssh_control_get_hostkey instead!
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  ssh-keyscan -T 30 $ILO_IP >> ~/.ssh/known_hosts
  local OUTPUT
  ( OUTPUT=`grep "$ILO_IP" ~/.ssh/known_hosts` ) || {
    echo "Failed to retrieve ipmi host key for $HOST!"
    return 1
  }

  local ALL_ILO_NAMES=`ilo_control_get_all_names $HOST`
  local NAME
  for NAME in $ALL_ILO_NAMES; do
    ssh-keyscan -T 30 $NAME >> ~/.ssh/known_hosts
    ( OUTPUT=`grep "$NAME" ~/.ssh/known_hosts` ) || {
      echo "Failed to retrieve host key for $NAME!"
      return 1
    }
  done
}


ilo_control_refetch_ilo_hostkey_these_hosts () {
  local PIDS="" HOST ILO_IP
  for HOST in $@; do
    ilo_control_remove_ilo_hostkey $HOST
  done
  for HOST in $@ now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        echo "Return code for PID $PID: $?"
      done
    else
      ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
      ilo_control_get_ilo_hostkey $HOST &
      PIDS="$PIDS:$!"
      echo "Getting host key for $HOST: $!"
    fi
  done
}

ilo_control_add_user () {
  local USER=$1 PASS=$2 HOST=$3

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local i COUNT=60 INTERVAL=10
  for i in `seq 1 $COUNT`; do
    OUTPUT=`ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l admin "create /map1/accounts1 username=$USER password=$PASS group=admin,config,oemhp_vm,oemhp_rc,oemhp_power"`
    [[ $? == 0 ]] && {
      break
    } || {
      echo "$OUTPUT" 1>&2
      echo "Problem adding user admin on $HOST!" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
}

ilo_control_add_ilo2_user_keys () {
  local HOST=$1

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  local i COUNT=60 INTERVAL=10
  for i in `seq 1 $COUNT`; do
    ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2_stack_cliff@loki.pub"
    [[ $? == 0 ]] && {
      break
    } || {
      echo $OUTPUT 1>&2
      echo "Problem setting keys for user stack on $HOST!" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
  for i in `seq 1 $COUNT`; do
    ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2_admin_cliff@loki.pub"
    [[ $? == 0 ]] && {
      break
    } || {
      echo $OUTPUT 1>&2
      echo "Problem setting keys for user admin on $HOST!" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
}

ilo_control_add_ilo4_user_keys () {
  local HOST=$1

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  local i COUNT=60 INTERVAL=10
  for i in `seq 1 $COUNT`; do
    ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
    [[ $? == 0 ]] && {
      break
    } || {
      echo $OUTPUT 1>&2
      echo "Problem setting keys on $HOST!" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
  for i in `seq 1 $COUNT`; do
    ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/accounts1/stack/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
    [[ $? == 0 ]] && {
      break
    } || {
      echo $OUTPUT 1>&2
      echo "Problem setting keys for user stack on $HOST!" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
  for i in `seq 1 $COUNT`; do
    ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/accounts1/admin/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
    [[ $? == 0 ]] && {
      break
    } || {
      echo $OUTPUT 1>&2
      echo "Problem setting keys for user admin on $HOST!" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
}
