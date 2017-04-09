#!/bin/bash

# watchdog script, that tracks requested system exec profiles.
# it will wait until NO OTHER exec profiles than tracked profiles is active,
# and then it terminates tracked profiles after some timeout.

# TODO: may be re-implemented in future with regular programming language like C
# if this script consumes too much resources.

# options:
# -b sandbox control_dir path
# -s sandboxer lock_path
# -w watchdog lock_path
# -l log file path
# -p tracked profile name (may be applied multiple times)
# -h show usage

showusage () {
  echo "usage: features_watchdog.sh <parameters>"
  echo "parameters:"
  echo "-b sandbox control_dir path"
  echo "-s sandboxer lock_path"
  echo "-w watchdog lock_path"
  echo "-l log file path"
  echo "-p tracked profile name (may be applied multiple times)"
  echo "-h show usage"
  exit 1
}

control_dir=""
sandbox_lock=""
watchdog_lock=""
logfile=""

profile_count=0
profile_storage=()

add_profile() {
  profile_storage[$profile_count]="$1"
  profile_count=$((profile_count+1))
}

parseopts () {
  local optname
  while getopts ":b:s:w:l:p:h" optname
  do
    case "$optname" in
      "b")
      control_dir="$OPTARG"
      ;;
      "s")
      sandbox_lock="$OPTARG"
      ;;
      "w")
      watchdog_lock="$OPTARG"
      ;;
      "l")
      logfile="$OPTARG"
      ;;
      "p")
      add_profile "$OPTARG"
      ;;
      "h")
      showusage
      ;;
      "?")
      echo "Unknown option $OPTARG"
      showusage
      ;;
      ":")
      echo "No argument given for option $OPTARG"
      showusage
      ;;
      *)
      # Should not occur
      echo "Unknown error while processing options"
      showusage
      ;;
    esac
  done
  [[ $profile_count = 0 ]] && echo "At least one profile must be set!" && showusage
  [[ -z $control_dir ]] && echo "Control dir must be set!" && showusage
  [[ -z $sandbox_lock ]] && echo "Sandboxer lock path must be set!" && showusage
  [[ -z $watchdog_lock ]] && echo "Watchdog lock path must be set!" && showusage
}

parseopts "$@"
