#!/bin/bash

THIS_SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# command-line options
DEBUG_ON=1                             # set default (off)
SAFE_MODE=1                            # set default (execute mode)
while getopts ":ds" opt; do
  case $opt in
    d) DEBUG_ON=1;;
    s) SAFE_MODE=1 ;;
    *) echo "Invalid option: -$OPTARG"; exit ;;
  esac
done

echo ""

if [ "$SAFE_MODE" -eq 1 ]; then
  SAFE_MODE_STRING="SAFE MODE: "
  echo -e "NOTE: [Running in SAFE MODE]\n"
fi

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
    "Run a plan/apply on a target module - master branch" \
    "Run a plan/apply on a master" \
    "Run a plan on a Feature Branch" \
    "Run a apply on a Feature Branch" \
    "Destroy module" \
    "Quit" \
  ; do
  case $action in
    "Run a plan/apply on a target module - master branch" ) plan_apply_target_module; break;;
    "Run a plan/apply on a master" ) plan_apply_from_master; break;;
    "Run a plan on a Feature Branch" ) plan_apply_from_feat_branch plan; break;;
    "Run a apply on a Feature Branch" ) plan_apply_from_feat_branch apply; break;;
    "Destroy module" ) destroy_target_module; break;;
    "Quit" ) exit_cleanly
  esac
done
exit_cleanly
}

function destroy_target_module 
{
  local target_module

  clone_and_checkout "master"
  
  read -p "Type the name of module you want to destroy: " target_module
  echo_info "You are going to destroy $target_module infrastructure!!!"
  do_or_die "run_terraform 'destroy' $target_module"
}

function plan_apply_target_module
{
  local target_module
  local user_response

  clone_and_checkout "master"

  read -p "Type the name of module you want to operate on: " target_module
  
  read -p "Do you want to plan or apply changes? (type 'plan' or 'apply' or 'q' to quit): " user_response
  if [ "$user_response" == "plan" ] 
  then
    do_or_die "run_terraform 'plan' $target_module"
  elif [ "$user_response" == "apply" ] 
  then
    do_or_die "run_terraform 'apply' $target_module"
  else 
    exit_cleanly "Exiting - no action taken"
  fi
}

function plan_apply_from_master
{
  local user_response

  clone_and_checkout "master"

  read -p "Do you want to plan or apply changes? (type 'plan' or 'apply' or 'q' to quit): " user_response
  if [ "$user_response" == "plan" ] 
  then
    do_or_die "run_terraform 'plan'"
  elif [ "$user_response" == "apply" ] 
  then
    do_or_die "run_terraform 'apply'"
  else 
    exit_cleanly "Exiting - no action taken"
  fi
}

function plan_apply_from_feat_branch
{
  local plan_or_apply=$1
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
          * ) if [ "$fb" ]; then selected_fb=$fb; break; fi
        esac
      done
    else
      exit_cleanly "ERROR: No unmerged branches found!"
    fi
  done

  if [[ "$selected_fb" =~ remotes/origin/(.*) ]]
  then
    local fb_name="${BASH_REMATCH[1]}"
  else
    exit_cleanly "Error in branch name"  
  fi

  echo -e "\nChecking out to: $fb_name..."
  do_or_die "git checkout $fb_name"

  run_terraform 'plan'

  exit_cleanly "Exiting - well done"
}

function clone_and_checkout
{
  local base_branch=$1

  echo -e "Cloning $CLOUD_SYTEMS_INFRASTRUCTURE_REPO ($base_branch)...\n"
  do_or_die "git clone $CLOUD_SYTEMS_INFRASTRUCTURE_REPO $REPO_NAME -b $base_branch"
  do_or_die "cd $REPO_NAME"
}

function run_terraform
{
  local plan_apply=$1
  local terraform_module=$2
  if [ -n "$terraform_module" ]; then
    local target_module_string="-target=module.$terraform_module"
  fi
  echo_info $target_module_string
  do_or_die 'terraform remote config -backend=s3 -backend-config="bucket=terraform-home-inf-state" -backend-config="key=home/terraform.tfstate" -backend-config="region=eu-west-1"'
  do_or_die 'terraform get'
  
  if [[ "$plan_apply" == "plan" ]]
  then 
    
    do_or_die 'terraform plan $target_module_string -var-file=environment/local/terraform.tfvars -input=false'
  elif [[ "$plan_apply" == "apply" ]]
  then
    do_or_die 'terraform plan $target_module_string -var-file=environment/local/terraform.tfvars -input=false'
    echo_info "Applying in 3 seconds..."
    sleep 3
    do_or_die_safe 'terraform apply $target_module_string -var-file=environment/local/terraform.tfvars -input=false'
  elif [[ "$plan_apply" == "destroy" ]] 
  then
    do_or_die 'terraform plan -destroy $target_module_string -var-file=environment/local/terraform.tfvars -input=false'
    do_or_die_safe 'terraform destroy -target=module.ecs -var-file=environment/local/terraform.tfvars -input=false'
  fi

}

function do_or_die
{
  local command=$1
  echo_info [$command]
  eval $command || exit_cleanly
}

function do_or_die_safe
{
  local command=$1
  if [ "$SAFE_MODE" != 0 ]; then
    echo "SAFE MODE: NOT EXECUTING: [$command]"
  else
    do_or_die "$command"
  fi
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

function confirm_or_exit
{
  local prompt=$1
  local answer

  local yn=""
  echo
  while [ ! $yn ]
  do
    read -p "$SAFE_MODE_STRING$prompt (y/n)? " answer
     case $answer in
         [yY] ) yn='y'; break;;
         [nN] ) yn='n'; break;;
     esac
  done

  if [ $yn != 'y' ]; then exit_cleanly; fi
}

main