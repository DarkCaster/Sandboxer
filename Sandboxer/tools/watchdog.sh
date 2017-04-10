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
# -c commander binary path
# -h show usage

showusage () {
  echo "usage: features_watchdog.sh <parameters>"
  echo "parameters:"
  echo "-b sandbox control_dir path"
  echo "-s sandboxer lock_path"
  echo "-w watchdog lock_path"
  echo "-l log file path"
  echo "-p tracked profile name (may be applied multiple times)"
  echo "-c commander binary path"
  echo "-h show usage"
  exit 1
}

commander_bin=""
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
  while getopts ":b:s:w:l:p:c:h" optname
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
      "c")
      commander_bin="$OPTARG"
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
  [[ -z $commander_bin ]] && echo "Commander binary path must be set!" && showusage
}

parseopts "$@"

watchdog_lock_enter() {
  local nowait="$1"
  if mkdir "$watchdog_lock" 2>/dev/null; then
    return 0
  else
    exit 0
  fi
}

watchdog_lock_exit() {
  rmdir "$watchdog_lock" 2>/dev/null
  true
}

watchdog_lock_enter

trap "{ watchdog_lock_exit; }" EXIT

trap "{ log \"dbus-watchdog: trap triggered, ignoring\"; }" SIGINT SIGHUP

log () {
  true
}

if [[ ! -z $logfile ]]; then
log () {
  echo "$@" >> "$logfile"
}
fi

sandbox_lock_entered="false"

sandbox_lock_enter() {
  local nowait="$1"
  if mkdir "$sandbox_lock" 2>/dev/null; then
    sandbox_lock_entered="true"
    return 0
  else
    [[ ! -z $nowait ]] && return 1
    log "awaiting lock release"
    while ! sandbox_lock_enter "nowait"; do
      sleep 1
    done
    sandbox_lock_entered="true"
    return 0
  fi
}

sandbox_lock_exit() {
  if [[ $sandbox_lock_entered = true ]]; then
    rmdir "$sandbox_lock" 2>/dev/null
    sandbox_lock_entered="false"
  fi
  true
}

check_session() {
  local session="$1"
  local el=""
  for el in "$control_dir"/*
  do
    [[ $el = "$control_dir/*" ]] && continue
    [[ $el =~ ^$session".in"$ || $el =~ ^$session".out"$ ]] && return 0
  done
  return 1
}

check_other_sessions() {
  local el=""
  local cnt=0
  local check=0
  for el in "$control_dir"/*
  do
    [[ $el = "$control_dir/*" ]] && continue
    [[ $el =~ ^.*".in"$ || $el =~ ^.*".out"$ ]] || continue
    check=0
    for ((cnt=0;cnt<profile_count;++cnt))
    do
      [[ $el =~ ^${profile_storage[$cnt]}".in"$ || $el =~ ^${profile_storage[$cnt]}".out"$ ]] && check=1
    done
    [[ $check = 0 ]] && return 0
  done
  return 1
}

#initial sleep
#sleep 10
