#!/bin/bash


_ilo_control_check_return_tags () {
  # SUCCESS:0    RETRY:1    EXIT:2
  local OUTPUT=$1

  local STATUS_TAG ERROR_TAG COMPLETED IN_POST

  local STATUS_TAG=$(echo "$OUTPUT" | grep "status_tag" | awk -F'=' '{print $2}')
  local ERROR_TAG=$(echo "$OUTPUT" | grep "error_tag" | awk -F'=' '{print $2}')
  local IN_POST=$(echo "$OUTPUT" | grep "unable to set boot orders until system completes POST.")

  [[ $DEBUG == "" ]] || {
    echo "CHECKING RETURN TAGS:" 1>&2
    echo "  STATUS_TAG: $STATUS_TAG" 1>&2
    echo "  ERROR_TAG: $ERROR_TAG" 1>&2
    echo "  IN_POST: $IN_POST" 1>&2
  }


  if [[ $IN_POST != "" ]] ; then
    echo "Server $HOST is in POST, retrying..." 1>&2
    return 1
  elif [[ $STATUS_TAG == "" ]] ; then
    # this is possibly an SSH glitch, not positive unidentified error...
    [[ $DEBUG == "" ]] || echo "$HOST Nonpositive error?  RETRYING..." 1>&2
    [[ $DEBUG == "" ]] || echo "$OUTPUT" 1>&2
    return 1
  elif [[ $STATUS_TAG == "COMMAND COMPLETED" ]]; then
    return 0
  elif [[ $STATUS_TAG == "COMMAND PROCESSING FAILED" ]]; then
    if [[ $ERROR_TAG == "COMMAND ERROR-UNSPECIFIED" ]]; then
      # THIS CAN HAPPEN ON ILO4 DURING POST, at least... Try Again.
      echo "COMMAND ERROR-UNSPECIFIED on $HOST.  In post?  RETRYING..." 1>&2
      [[ $DEBUG == "" ]] || echo "$OUTPUT" 1>&2
      return 1
    elif [[ $ERROR_TAG == "COMMAND NOT RECOGNIZED" ]]; then
      echo "ILLEGAL ILO COMMAND on $HOST!!!  EXITING!!!" 1>&2
      return 2
    elif [[ $ERROR_TAG == "INVALID OPTION" ]]; then
      # This can happen when ILO's busy or in POST
      echo "INVALID OPTION on $HOST.  In post?  RETRYING..." 1>&2
      [[ $DEBUG == "" ]] || echo "$OUTPUT" 1>&2
      return 1
    else
      echo "UNKNOWN ERROR ON $HOST:" 1>&2
      echo "     STATUS_TAG=$STATUS_TAG" 1>&2
      echo "     ERROR_TAG=$ERROR_TAG" 1>&2
      echo "     EXITING!!!" 1>&2
      [[ $DEBUG == "" ]] || echo "$OUTPUT" 1>&2
      return 2
    fi
  else
    echo "UNKNOWN ERROR ON $HOST: STATUS_TAG=$STATUS_TAG, EXITING!!!" 1>&2
    [[ $DEBUG == "" ]] || echo "$OUTPUT" 1>&2
    return 2
  fi
  # DON'T ASSUME SUCCESS...  May find success conditions with infinite retry loops...
  return 1
}


_ilo_control_run_command () {
  local HOST=$1 ILO_COMMAND=$2 CALLING_FUNC=$3
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  [[ $DEBUG == "" ]] || {
    echo "___________________" 1>&2
    echo "In $CALLING_FUNC, about to send ILO command: $ILO_COMMAND" 1>&2
  }
  local INTERVAL=10
  while true; do
    local OUTPUT=$(ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l stack "$ILO_COMMAND" | tr '\r' '\n' | sed 's/\n\n/\n/g')

    [[ $DEBUG == "" ]] || {
      echo "Calling _ilo_control_check_return_tags from $CALLING_FUNC..." 1>&2
    }
    _ilo_control_check_return_tags "$OUTPUT"
    ILO_COMMAND_STATUS=$?
    [[ $DEBUG == "" ]] || {
      echo "_ilo_control_check_return_tags returned STATUS=$ILO_COMMAND_STATUS" 1>&2
    }

    if [[ $ILO_COMMAND_STATUS == 1 ]]; then
      [[ $DEBUG == "" ]] || echo "Command encountered retryable failure, retrying." 1>&2
      sleep $INTERVAL
    else
      [[ $DEBUG == "" ]] || echo "___________________" 1>&2
      if [[ $ILO_COMMAND_STATUS == 0 ]]; then
        [[ $DEBUG == "" ]] || echo "Command successfully run." 1>&2
        echo "$OUTPUT"
        return 0
      elif [[ $ILO_COMMAND_STATUS == 2 ]]; then
        [[ $DEBUG == "" ]] || echo "Command encountered total failure, EXITING!!" 1>&2
        return 2
      else
        echo "INVALID RETURN CODE, SHOULDN'T HAPPEN, EXITING!!!" 1>&2
        return 2
      fi
    fi
  done
}


ilo_control_get_all_names () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`
  local ILO_NAMES=`grep "$ILO_IP " /etc/hosts | sed 's/^[^ ]*[ ]*//g'`
  echo $ILO_NAMES
}

ilo_control_get_hw_gen () {
  local HOST=$1
  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local ILO_COMMAND="show system1 name"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_control_get_hw_gen`
  ILO_COMMAND_STATUS=$?
  local GENERATION=`echo "$OUTPUT" | grep "name=" | tr '\r' ' ' | awk -F'=' '{print $2}' | awk '{print $3}'`

  if [[ $ILO_COMMAND_STATUS == 0 ]]; then
    if [[ $GENERATION == G6 ]]; then
      echo 6; return 0
    elif [[ $GENERATION == Gen8 ]]; then
      echo 8; return 0
    fi
  else
    echo "Problem getting hw generation info on $HOST!" 1>&2
    return 1
  fi
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

  local COUNT=10 INTERVAL=10
  for i in `seq 1 $COUNT`; do
    # Can't call _ilo_control_run_command because it assumes user stack... For now.
    local OUTPUT=`ssh -i ~/.ssh/id_rsa_ilo2 $ILO_IP -l admin "create /map1/accounts1 username=$USER password=$PASS group=admin,config,oemhp_vm,oemhp_rc,oemhp_power"`
    [[ $? == 0 ]] && {
      break
    } || {
      echo "$OUTPUT" 1>&2
      echo "Problem adding user $USER on $HOST! ILO" 1>&2
      [[ $i < $COUNT ]] && { echo "Retrying in $INTERVAL seconds." 1>&2; sleep $INTERVAL; }
    }
  done
}

ilo_control_add_ilo2_user_keys () {
  local HOST=$1

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local ILO_COMMAND="oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2_stack_cliff@loki.pub"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_control_add_ilo2_user_keys`
  [[ $? == 0 ]] && {
    echo "User stack keys added to $HOST ILO." 1>&2
  } || {
    echo "$OUTPUT" 1>&2
    echo "Problem setting keys for user stack on $HOST ILO!" 1>&2
  }

  ILO_COMMAND="oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2_admin_cliff@loki.pub"
  OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_control_add_ilo2_user_keys`
  [[ $? == 0 ]] && {
    echo "User stack keys added to $HOST ILO." 1>&2
  } || {
    echo "$OUTPUT" 1>&2
    echo "Problem setting keys for user admin on $HOST ILO!" 1>&2
  }
}

ilo_control_add_ilo4_user_keys () {
  local HOST=$1

  local ILO_IP=`getent hosts $HOST-ipmi | awk '{print $1}' | tail -n 1`

  local ILO_COMMAND="oemhp_loadSSHKey /map1/config1/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_control_add_ilo4_user_keys`
  [[ $? == 0 ]] && {
    echo "User keys added to $HOST ILO." 1>&2
  } || {
    echo "$OUTPUT" 1>&2
    echo "Problem setting keys on $HOST ILO!" 1>&2
  }

  ILO_COMMAND="oemhp_loadSSHKey /map1/accounts1/stack/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
  OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_control_add_ilo4_user_keys`
  [[ $? == 0 ]] && {
    echo "User stack keys added to $HOST ILO." 1>&2
  } || {
    echo "$OUTPUT" 1>&2
    echo "Problem setting keys for user stack on $HOST!" 1>&2
  }

  local ILO_COMMAND="oemhp_loadSSHKey /map1/accounts1/admin/ -source http://192.168.1.82:8080/share/ssh_keys/id_rsa_ilo2.pub"
  local OUTPUT=`_ilo_control_run_command $HOST "$ILO_COMMAND" ilo_control_add_ilo4_user_keys`
  [[ $? == 0 ]] && {
    echo "User admin keys added to $HOST ILO." 1>&2
  } || {
    echo "$OUTPUT" 1>&2
    echo "Problem setting keys for user admin on $HOST!" 1>&2
  }
}
