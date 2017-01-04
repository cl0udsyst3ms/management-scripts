#!/bin/bash

THIS_SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# command-line options
DEBUG_ON=0                             # set default (off)
SAFE_MODE=0                            # set default (execute mode)
while getopts ":ds" opt; do
  case $opt in
    d) DEBUG_ON=1;;
    s) SAFE_MODE=1 ;;
    *) echo "Invalid option: -$OPTARG"; exit ;;
  esac
done

echo ""

REPO_NAME="cloudsys-infrastructure"
CLOUD_SYTEMS_INFRASTRUCTURE_REPO="git@github.com:cl0udsyst3ms/$REPO_NAME.git"
# $$ - PID
WORKING_DIR="terraform_temp_plan_apply$$"

function main()
{
  local action

  do_or_die "mkdir /tmp/$WORKING_DIR"
  do_or_die "cd /tmp/$WORKING_DIR"

  echo_debug "REPO: $CLOUD_SYTEMS_INFRASTRUCTURE_REPO"
  echo_debug "Working directory: /tmp/$WORKING_DIR"
  echo_debug "SAFE_MODE=$SAFE_MODE"

  echo -e "\nOkay, what do you want to do..."
  select action in \
    "Run a plan on a Feature Branch" \
    "Quit" \
  ; do
  case $action in
    "Run a plan on a Feature Branch" ) plan_apply_from_feat_branch plan; break;;
    "Quit" ) exit_cleanly
  esac
done
exit_cleanly
}


function plan_apply_from_feat_branch
{
  local plan_or_apply='plan'
  local selected_fb
  local fb

  clone_and_checkout "master"

  # Select the feature branch to test...
  while [ ! "$selected_fb" ]
  do
    echo
 
    # The feature branch that the user wants to test should be amongst those returned by the following command
    local feature_branches=`git branch --all --list $feature_branch_pattern --no-merged` || exit_cleanly
    if [ "$feature_branches" ]
    then
      echo -e "Select the feature branch you want to test..."
      select fb in $feature_branches "Quit"
      do
        case $fb in
          "Quit" ) exit_cleanly;;
          "Re-enter Jira ticket number..." ) break;;
          * ) if [ "$fb" ]; then selected_fb=$fb; exit_cleanly "Add code here"; fi
        esac
      done
    else
      exit_cleanly "ERROR: No unmerged branches found!"
    fi
  done
}

function clone_and_checkout
{
  local base_branch=$1

  echo -e "Cloning $CLOUD_SYTEMS_INFRASTRUCTURE_REPO ($base_branch)...\n"
  do_or_die "git clone $CLOUD_SYTEMS_INFRASTRUCTURE_REPO $REPO_NAME -b $base_branch"
  do_or_die "cd $REPO_NAME"
}

if [ "$SAFE_MODE" -eq 1 ]; then
  SAFE_MODE_STRING="SAFE MODE: "
  echo -e "NOTE: [Running in SAFE MODE]\n"
fi

function do_or_die
{
  local command=$1
  echo_info [$command]
  eval $command || exit_cleanly
}

function exit_cleanly
{
  # optional message
  if [ "$1" ]; then
    echo -e "\n$1"
  fi

  echo_debug "exit_cleanly"

  rm -rf /tmp/$WORKING_DIR

  exit 0
}

function echo_info
{
  echo -e "INFO: $*"
}

function echo_debug
{
  if [ "$DEBUG_ON" != 0 ]; then echo -e "DEBUG: $*"; fi
}


main