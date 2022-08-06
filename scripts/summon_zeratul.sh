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


wget --method=POST https://eac23562-bfe2-485a-a3c8-75781b177934.webhook.eus.azure-automation.net/webhooks?token=fme0bUj8P%2f%2bzp%2frV58Co8kMJFQV58EXPY%2bxfVGk1g1Y%3d

SLEEP=30
TRIES=20

for TRY in $(seq 1 $TRIES); do
  echo Try $TRY of $TRIES.
  SHUTDOWN_LOCK=/tmp/no_shutdown
  ssh -o ConnectTimeout=3 zeratul.feralcoder.org hostname && {
    ssh -o ConnectTimeout=3 zeratul.feralcoder.org touch $SHUTDOWN_LOCK
    echo ZERATUL HAS BEEN SUMMONED
    return
  }
  echo Zeratul still not reachable.
  echo Sleeping for $SLEEP seconds.
  sleep $SLEEP
done
