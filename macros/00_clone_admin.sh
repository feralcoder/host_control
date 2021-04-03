#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/feralcoder/host_control/control_scripts.sh

fail_exit () {
  local ERROR=$1
  echo "Failing Out! $ERROR"
  exit 1
}

HOST=$1
[[ $HOST != "" ]] || {
  echo "Must supply host, and run from current admin host!"
  exit 1
}


setup_admin () {
  ilo_control_refetch_ilo_hostkey_these_hosts $HOST                                                  || fail_exit "refetch ilo key for target"
  ssh_control_refetch_hostkey_these_hosts $HOST                                                      || fail_exit "refetch host key for target"
  ssh_control_distribute_admin_key_these_hosts $HOST                                                 || fail_exit "push admin keys"
  ssh_control_sync_as_user cliff ~/.password ~/.password $HOST                                       || fail_exit "sync .password"
  ssh_control_sync_as_user cliff ~/.git_password ~/.git_password $HOST                               || fail_exit "sync .git_password"
  ssh_control_run_as_user root "yum -y install git tmux" $HOST                                       || fail_exit "yum install git tmux"
  ssh_control_run_as_user cliff "mkdir -p ~/CODE/feralcoder" $HOST                                   || fail_exit "make code directory"
  ssh_control_run_as_user cliff "cd ~/CODE/feralcoder && ( [[ -d bootstrap-scripts ]] || git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/bootstrap-scripts.git )" $HOST || fail_exit "git checkout bootstrap"
  ssh_control_run_as_user cliff "cd ~/CODE/feralcoder/bootstrap-scripts && ./admin.sh" $HOST         || fail_exit "git run bootstrap"
}


setup_admin
