#!/bin/bash


ilo_control_get_hw_gen () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
  local GENERATION

  local TRY TRIES=5 INTERVAL=10
  for TRY in `seq 1 $TRIES`; do
    GENERATION=`ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "show system1 name" | grep "name=" | awk -F'=' '{print $2}' | awk '{print $3}'`
    [[ $? == "0" ]] && {
      if [[ $GENERATION == "G6" ]]; then
        echo 6; return 0
      elif [[ $GENERATION == "Gen8" ]]; then
        echo 8; return 0
      fi
    }
    sleep $INTERVAL
  done
  return 1
}

ilo_control_remove_ilo_hostkey () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
  ssh-keygen -R $ILO_IP
}

ilo_control_get_ilo_hostkey () {
  ssh-keyscan -T 30 $ILO_IP >> ~/.ssh/known_hosts
  local OUTPUT
  ( OUTPUT=`grep "$ILO_IP" ~/.ssh/known_hosts` ) || {
    echo "Failed to retrieve ipmi host key for $HOST!"
    return 1
  }
}

ilo_control_get_ilo_hostkey_these_hosts () {
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
      ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
      ilo_control_get_ilo_hostkey $HOST &
      PIDS="$PIDS:$!"
      echo "Getting host key for $HOST: $!"
    fi
  done
}

ilo_control_add_user () {
  local USER=$1 PASS=$2 HOST=$3

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`

  ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l admin "create /map1/accounts1 username=$USER password=$PASS group=admin,config,oemhp_vm,oemhp_rc,oemhp_power"
}

ilo_control_add_ilo2_user_keys () {
  local HOST=$1

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
  ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2_stack_cliff@loki.pub"
  ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2_admin_cliff@loki.pub"
}

ilo_control_add_ilo4_user_keys () {
  local HOST=$1

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}'`
  ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
  ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/accounts1/stack/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
  ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "oemhp_loadSSHKey /map1/accounts1/admin/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
}
