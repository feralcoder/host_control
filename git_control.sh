#!/bin/bash -x

REPOS="bootstrap-scripts  host_control  kolla-ansible  workstation  workstation.wiki"
CODE_PATH=/home/cliff/CODE/feralcoder/


git_control_set_local_password () {
  echo "Setting new local git password..."
  local PASSFILE=`ssh_control_get_password ~/.git_password false`
}

git_control_fix_repos () {
  local HOST=$1

  [[ -f ~/.git_password ]] || git_control_set_local_password
  ssh_control_sync_as_user cliff ~/.git_password ~/.git_password $HOST

  local REPO REPO_PATH
  for REPO in $REPOS; do
    REPO_PATH=$CODE_PATH/$REPO
    FIXPASS_CMD='sed -i "s/feralcoder:[^@]*/feralcoder:`cat ~/.git_password`/g" .git/config'
    ssh_control_run_as_user cliff "echo Fixing $REPO on \`hostname\`; if [[ -d $REPO_PATH ]]; then cd $REPO_PATH && $FIXPASS_CMD 2>&1; else echo $REPO_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" $HOST
    echo; echo
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
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Fix repos, no more info available"
        fi
      done
    else
      git_control_fix_repos $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Fixing repos on $HOST..."
    fi
  done
}

git_control_pull_push () {
  local HOST=$1

  local REPO REPO_PATH
  for REPO in $REPOS; do
    REPO_PATH=$CODE_PATH/$REPO
    ssh_control_run_as_user_these_hosts cliff "echo Fetch-Pushing $REPO on $HOST; if [[ -d $REPO_PATH ]]; then cd $REPO_PATH && git pull 2>&1 ; PULL_ERROR=\$? ; if [[ \$PULL_ERROR == 0 ]]; then git push; else echo 'COULD NOT PULL $REPO on $HOST, Changes to stash?' ; fi; 2>&1; else echo $REPO_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" $HOST
    echo; echo
  done
}

git_control_pull_push_these_hosts () {
  local HOSTS=$1

  local RETURN_CODE PID
  for HOST in $HOSTS now_wait; do
    if [[ $HOST == "now_wait" ]]; then
      PIDS=`echo $PIDS | sed 's/^://g'`
      for PID in `echo $PIDS | sed 's/:/ /g'`; do
        wait ${PID} 2>/dev/null
        RETURN_CODE=$?
        if [[ $RETURN_CODE != 0 ]]; then
          echo "Return code for PID $PID: $RETURN_CODE"
          echo "Pull push repos, no more info available"
        fi
      done
    else
      git_control_pull_push $HOST & 2>/dev/null
      PIDS="$PIDS:$!"
      echo "Fetch-Push-ing repos on $HOST..."
    fi
  done
}

git_control_stash_explore () {
  local HOST=$1
  local REPO REPO_PATH
  for REPO in $REPOS; do
    REPO_PATH=$CODE_PATH/$REPO
    ssh_control_run_as_user_these_hosts cliff "echo Exploring Git Stashes in $REPO on $HOST; if [[ -d $REPO_PATH ]]; then cd $REPO_PATH && git stash list && git stash show -p && echo 'VS Working Copy:' && git diff stash@{0} 2>&1; else echo $REPO_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" $HOST
    echo; echo
  done
}

git_control_stash_changes () {
  local STASH_REPOS=$1 HOST=$2
  for REPO in $STASH_REPOS; do
    REPO_PATH=$CODE_PATH/$REPO
    ssh_control_run_as_user_these_hosts cliff "echo Stashing Changes in Git Repo $REPO on $HOST; if [[ -d $REPO_PATH ]]; then cd $REPO_PATH && git stash 2>&1; else echo $REPO_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" $HOST
    echo; echo
  done
}

git_control_stash_drop () {
  local CLEAN_REPOS=$1 HOST=$2
  for REPO in $CLEAN_REPOS; do
    REPO_PATH=$CODE_PATH/$REPO
    ssh_control_run_as_user_these_hosts cliff "echo Cleaning Git Stashes in $REPO on $HOST; if [[ -d $REPO_PATH ]]; then cd $REPO_PATH && git stash drop 2>&1; else echo $REPO_PATH DOES NOT EXIST ON \`hostname\`; fi; echo; echo" $HOST
    echo; echo
  done
}
