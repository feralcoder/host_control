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
  ssh_control_sync_as_user cliff ~/.password ~/.password $HOST || fail_exit "sync .password"
  ssh_control_sync_as_user cliff ~/.git_password ~/.git_password $HOST || fail_exit "sync .git_password"
  yum -y install git tmux || fail_exit "yum install git tmux"
  ssh_control_run_as_user cliff "cd ~/CODE/feralcoder && git clone https://feralcoder:`cat ~/.git_password`@github.com/feralcoder/bootstrap-scripts.git" $HOST || fail_exit "git checkout bootstrap"
}


setup_admin
