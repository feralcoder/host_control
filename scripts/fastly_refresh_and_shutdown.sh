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
  exit
fi

$THIS_SOURCE/fastly_refresh.sh
SHUTDOWN_LOCK=/tmp/no_shutdown
if [[ ! -f $SHUTDOWN_LOCK ]]; then
  sudo shutdown now
else
  echo "I would shut down but $SHUTDOWN_LOCK says not to!"
fi
