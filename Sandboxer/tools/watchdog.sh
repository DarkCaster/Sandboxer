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
  echo "-k commander's security key"
  echo "-h show usage"
  exit 1
}

commander_bin=""
security_key=""
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
  while getopts ":b:s:w:l:p:c:k:h" optname
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
      "k")
      security_key="$OPTARG"
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
  [[ -z $security_key ]] && echo "Security key must be set!" && showusage
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
  echo "$@"
}

if [[ ! -z $logfile ]]; then
log () {
  echo "$@" # debug
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
  [[ -e "$control_dir/$1.in" || -e "$control_dir/$1.out" ]] && return 0 || return 1
}

check_other_sessions() {
  local el=""
  local cnt=0
  local check=0
  for el in "$control_dir"/*
  do
    [[ $el = "$control_dir/*" ]] && continue
    [[ $el =~ ^.*".in"$ || $el =~ ^.*".out"$ ]] || continue
    [[ $el =~ ^.*"/control.in"$ || $el =~ ^.*"/control.out"$ ]] && continue
    check=0
    for ((cnt=0;cnt<profile_count;++cnt))
    do
      [[ $el =~ ^.*"/"${profile_storage[$cnt]}".in"$ || $el =~ ^.*"/"${profile_storage[$cnt]}".out"$ ]] && check=1
    done
    [[ $check = 0 ]] && return 0
  done
  return 1
}

wait_for_session_exit() {
  local session="$1"
  local wait_ticks=400
  while check_session "$session"
  do
    if [[ $wait_ticks -lt 1 ]]; then
      log "timeout while waiting for $session session termination"
      return 1
    fi
    sleep 0.025
    wait_ticks=$((wait_ticks-1))
  done
  return 0
}

terminate_session() {
  local session="$1"
  log "requesting $session session to grace exit"
  [[ -z $logfile ]] && \
  { "$commander_bin" "$control_dir" "$session" "$security_key" 253 1; \
    [[ $? != 0 ]] && log "failed to send command to $session session" && return 1; } || \
  { &>>"$logfile" "$commander_bin" "$control_dir" "$session" "$security_key" 253 1; \
    [[ $? != 0 ]] && log "failed to send command to $session session" && return 1; }
  wait_for_session_exit $session && return 0 || return 1
}

kill_session() {
  local session="$1"
  log "requesting $session session to force quit"
  [[ -z $logfile ]] && \
  { "$commander_bin" "$control_dir" "$session" "$security_key" 253 0; \
    [[ $? != 0 ]] && log "failed to send command to $session session" && return 1; } || \
  { &>>"$logfile" "$commander_bin" "$control_dir" "$session" "$security_key" 253 0; \
    [[ $? != 0 ]] && log "failed to send command to $session session" && return 1; }
  wait_for_session_exit $session && return 0 || return 1
}

while true
do
  #check, that there are slave sessions active other than tracked sessions
  if check_other_sessions; then
    #sleep and continue, if true
    log "check_other_sessions #1, succeed" # debug
    sleep 5
    continue
  fi

  #enter lock
  sandbox_lock_enter

  #final check before termination.
  #running with sandbox locking to prevent concurrent sandboxer.sh script run.
  if check_other_sessions; then
    #exit lock and continue, if true
    sandbox_lock_exit
    log "check_other_sessions #2, succeed" # debug
    sleep 5
    continue
  fi

  # iterate through session-list backwards
  for ((cnt=profile_count-1;cnt>-1;--cnt))
  do
    log "terminating ${profile_storage[cnt]}" # debug
    # terminate\kill session
    terminate_session "${profile_storage[cnt]}" || kill_session "${profile_storage[cnt]}"
  done

  #exit lock
  sandbox_lock_exit
  break

done

exit 0
