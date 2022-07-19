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

LOCK_FILE=/tmp/fastly_refresh_lock
if [[ -f $LOCK_FILE ]]; then
  echo "It appears another refresh process is already running."
  echo "If this is not the case, then remove $LOCK_FILE and try again."
  exit 1
else
  touch $LOCK_FILE

  WIKI_CHECKOUTS="$USER_DIR/CODE/feralcoder/workstation.wiki $USER_DIR/CODE/feralcoder/shared.wiki"
  for WIKI in $WIKI_CHECKOUTS; do
    cd $WIKI
    git pull
    wiki_control_warm_fastly_cache
  done
  rm $LOCK_FILE
fi
