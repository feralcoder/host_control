#!/bin/bash
MACRO_SOURCE="${BASH_SOURCE[0]}"
MACRO_DIR=$( dirname $MACRO_SOURCE )
# THIS SCRIPT ALSO USED FOR UPDATES - MAINTAIN IT AS SUCH

# BAIL OUT IF USER SOURCES SCRIPT, INSTEAD OF RUNNING IT
if [ ! "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "Do not source this script (exits will bail you...)."
  echo "Run it instead"
  return 1
fi

. ~/CODE/feralcoder/host_control/control_scripts.sh

# This script is suitable to run after the post-install host scripts
#   (00a_new_install_no_admin_key.sh  00b_new_admin_key_on_host.sh  00c_new_install_with_existing_admin_key.sh)

REPO_HOST=dumbledore

NOW=`date +%Y%m%d-%H%M%S`

HOSTS=$1
[[ $HOSTS == "" ]] && {
  echo "No hosts provided.  You must provide a list of hosts to update."
  exit 1
}



host_control_setup_host_access () {
  local HOSTS=$1

  echo; echo "REFETCHING LOCAL KNOWN HOSTKEYS FOR $HOSTS"
  # Make sure this host recognizes all others
  ssh_control_refetch_hostkey_these_hosts "$HOSTS"
  echo; echo "RESETTING ADMIN KEYS on $HOSTS"
  # Redistribute admin pubkeys to cliff/root users everywhere
  ssh_control_distribute_admin_key_these_hosts "$HOSTS"

  echo; echo "REFETCHING ILO KEYS LOCALLY"
  ilo_control_refetch_ilo_hostkey_these_hosts "$HOSTS"
}

setup_repo_mirror () {
  local REPO_HOST=$1
  [[ REPO_HOST != "" ]] || { echo "No REPO_HOST supplied!"; exit 1; }
  ssh_control_run_as_user root "dnf list installed git || dnf -y install git" $REPO_HOST || return 1
  os_control_setup_repo_mirror $REPO_HOST || return 1
}


admin_setup () {
  local HOSTS=$1
  local HOST
  # This is where $REPO_HOST will get its git
  ssh_control_run_as_user_these_hosts root "dnf list installed git || dnf -y install git" "$HOSTS"
  for HOST in $HOSTS; do
    if ( ssh_control_run_as_user cliff "ls -al ~/.local_settings" $HOST ) || [[ ${FORCEBOOTSTRAP,,} == true ]] ; then
      admin_control_bootstrap_admin $HOST
    else
      echo "It seems admin has already been bootstrapped on $HOST."
      echo "Run with FORCEBOOTSTRAP=true to re-bootstrap."
    fi
  done
  ssh_control_run_as_user_these_hosts cliff "~/CODE/feralcoder/workstation/update.sh" "$HOSTS"
}


host_control_updates () {
  local HOSTS=$1

  # Who doesn't need a good /tmp/x.  Right?
  ssh_control_run_as_user_these_hosts root "touch /tmp/x" "$HOSTS"

  echo; echo "REPOINTING YUM TO LOCAL MIRROR ON $HOSTS"
  os_control_checkout_repofetcher `hostname`
  os_control_repoint_repos_to_feralcoder_these_hosts "$HOSTS"

  # Some basic packages...
  # This is where all non-$REPO_HOST hosts will get their gits
  ssh_control_run_as_user_these_hosts root "dnf list installed git || dnf -y install git" "$HOSTS"
  ssh_control_run_as_user_these_hosts root "dnf list installed telnet || dnf -y install telnet" "$HOSTS"

  admin_setup "$HOSTS"

  echo; echo "UPDATING GIT REPOS EVERYWHERE"
  git_control_pull_push_these_hosts "$HOSTS" 2>/dev/null
}

refetch_keys () {
  # Serialize to not DOS ILO's and HOSTS
  for HOST in $HOSTS; do
    echo; echo "REFETCHING HOST KEYS on $HOST"
    ssh_control_run_as_user cliff "ssh_control_refetch_hostkey_these_hosts \"$HOSTS\"" $HOST 2>/dev/null
    echo; echo "Getting ILO hostkeys on $HOST"
    ssh_control_run_as_user cliff "ilo_control_refetch_ilo_hostkey_these_hosts \"$HOSTS\"" $HOST 2>/dev/null
  done
}

setup_perftools () {
  local HOSTS=$1
  ssh_control_run_as_user_these_hosts root "dnf -y install bcc perf systemtap" "$HOSTS"
  ssh_control_run_as_user_these_hosts cliff "mkdir -p ~/CODE/brendangregg && cd ~/CODE/brendangregg && git clone https://github.com/brendangregg/perf-tools.git || ( cd ~/CODE/brendangregg/perf-tools && git pull )" "$HOSTS"

  ssh_control_run_as_user_these_hosts cliff "( grep 'PATH.*share.bcc.tools' .bash_profile ) && sed -i 's|.*PATH.*share.bcc.tools.*|export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools|g' .bash_profile || echo 'export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools' >> ~/.bash_profile" "$STACK_HOSTS"
  ssh_control_run_as_user_these_hosts root "( grep 'PATH.*share.bcc.tools' .bash_profile ) && sed -i 's|.*PATH.*share.bcc.tools.*|export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools|g' .bash_profile || echo 'export PATH=\$PATH:/usr/share/bcc/tools:~cliff/CODE/brendangregg/perf-tools' >> ~/.bash_profile" "$STACK_HOSTS"
}



host_updates () {
  local HOSTS=$1

  echo; echo "UPDATING YUM ON $HOSTS, see output in logfile /tmp/yum_update_$NOW.log"
  ssh_control_run_as_user_these_hosts root "dnf -y upgrade | tee /tmp/yum_update_$NOW.log" "$HOSTS"
  
  echo; echo "UPDATING GRUB ON $HOSTS"
  admin_control_fix_grub_these_hosts "$HOSTS"
}



SUDO_PASS_FILE=`admin_control_get_sudo_password ~/.password`
host_control_setup_host_access "$HOSTS"              || exit 1
# admin_setup is also called from host_control_updates - will be called twice on $REPO_HOST...  Oh well.
FORCEBOOTSTRAP=true admin_setup $REPO_HOST           || exit 1
setup_repo_mirror $REPO_HOST                         || exit 1
FORCEBOOTSTRAP=true host_control_updates "$HOSTS"    || exit 1
refetch_keys                                         || exit 1
host_updates "$HOSTS"                                || exit 1
setup_perftools "$HOSTS"

[[ $SUDO_PASS_FILE != ~/.password ]] && rm $SUDO_PASS_FILE
