#!/bin/bash
THIS_SOURCE="$(dirname ${BASH_SOURCE[0]})"
echo Running scripts from: $THIS_SOURCE

. $THIS_SOURCE/../control_scripts.sh

USER_DIR=$(
  if [[ -d ~cliff ]]; then
    echo ~cliff
  elif [[ -d ~feralcoder ]]; then
    echo ~feralcoder
  else
    echo ''
  fi
)
if [[ $USER_DIR == '' ]]; then
  echo "Unable to determine admin user on system.  Not 'cliff' or 'feralcoder'."
  exit 1
fi

EPOCH_TIME=$(date +%s)

LOCK_FILE=/tmp/fastly_refresh_lock
if [[ -f $LOCK_FILE ]]; then
  LAST_TIME=$(cat $LOCK_FILE)
  ELAPSED=$(( $EPOCH_TIME - $LAST_TIME ))
  if [[ $ELAPSED -lt 7200 ]]; then
    echo; echo "It appears another refresh process is already running."
    echo "It started $ELAPSED seconds ago."
    echo "If this is not the case, then remove $LOCK_FILE and try again."
    exit 1
  else
    echo; echo "It appears another refresh process started over 2 hours ago and did not finish."
    echo "Checking for old process..."
    OLD_PROCS=$( ps aux | grep scripts.fastly_refresh.sh | grep bin.bash )
    if [[ $OLD_PROCS != "" ]]; then
      OLD_PIDS=$( echo "$OLD_PROCS" | awk '{print $2}' )
      echo; echo "Found old processes:"
      echo "$OLD_PROCS"
      echo; echo Killing PIDS: $OLD_PIDS
      kill -9 $OLD_PIDS
    else
      echo; echo "No old processes found."
    fi
    rm $LOCK_FILE
  fi
fi




echo $EPOCH_TIME > $LOCK_FILE

WIKI_CHECKOUTS="$USER_DIR/CODE/feralcoder/workstation.wiki $USER_DIR/CODE/feralcoder/shared.wiki"
for WIKI in $WIKI_CHECKOUTS; do
  cd $WIKI
  git pull
  wiki_control_warm_fastly_cache
done
rm $LOCK_FILE
