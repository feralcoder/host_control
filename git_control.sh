#!/bin/bash -x

REPOS="bootstrap-scripts  host_control  kolla-ansible  workstation  workstation.wiki"

git_control_set_local_password () {
  echo "Setting new local git password..."
  local PASSFILE=`ssh_control_get_password`
  mv $PASSFILE ~/.git_password && chmod 600 ~/.git_password
}

git_control_fix_repos () {
  local HOST=$1

  [[ -f ~/.git_password ]] || git_control_set_local_password
  ssh_control_sync_as_user cliff ~/.git_password ~/.git_password $HOST
  
  local REPO
  for REPO in $REPOS; do
    CODE_PATH=/home/cliff/CODE/feralcoder/$REPO
    FIXPASS_CMD='sed -i "s/feralcoder:[^@]*/feralcoder:`cat ~/.git_password`/g" .git/config'
    ssh_control_run_as_user cliff "echo Fixing $REPO on \`hostname\`; if [[ -d $CODE_PATH ]]; then cd $CODE_PATH && $FIXPASS_CMD 2>&1; else echo $CODE_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" $HOST
  done
}

git_control_fix_repos_these_hosts () {
  local HOSTS=$1

  [[ -f ~/.git_password ]] || git_control_set_local_password

  local RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $?"
        fi
      done
    else
      git_control_fix_repos $HOST &
      PIDS="$PIDS:$!"
      echo "Fixing repos on $HOST..."
    fi
  done
}

git_control_pull_push () {
  HOST=$1

  local REPO
  for REPO in $REPOS; do
    CODE_PATH=/home/cliff/CODE/feralcoder/$REPO
    ssh_control_run_as_user_these_hosts cliff "echo Fetch-Pushing $REPO on $HOST; if [[ -d $CODE_PATH ]]; then cd $CODE_PATH && git stash && git pull && git stash apply && git push 2>&1; else echo $CODE_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" $HOST
  done
}

git_control_pull_push_these_hosts () {
  HOST=$1

  local RETURN_CODE
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      local PID
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID}
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $?"
        fi
      done
    else
      git_control_pull_push $HOST &
      PIDS="$PIDS:$!"
      echo "Fetch-Push-ing repos on $HOST..."
    fi
  done
}
