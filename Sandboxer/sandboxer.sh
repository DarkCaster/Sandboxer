#!/bin/bash

#detection of actual script location
curdir="$PWD"
script_dir="$( cd "$( dirname "$0" )" && pwd )"
self=`basename "$0"`
test ! -e "$script_dir/$self" && echo "script_dir detection failed. cannot proceed!" && exit 1
script_file=`readlink "$script_dir/$self"`
test ! -z "$script_file" && script_dir=`realpath \`dirname "$script_file"\``

#load parameters
config="$1"
test -z "$config" && echo "usage: sandboxer.sh <config file> <exec profile> [other parameters, will be forwarded to executed app]" && exit 1
shift 1
profile="$1"
test -z "$profile" && echo "usage: sandboxer.sh <config file> <exec profile> [other parameters, will be forwarded to executed app]" && exit 1
shift 1

#includes dir
includes_dir="$script_dir/includes"

#activate some loadables
. "$includes_dir/loadables-helper.bash.in"

#generate uid for given config file
test ! -e "$config" && echo "config file not found: $config" && exit 1
config_uid=`realpath -s "$config" | md5sum -t | cut -f1 -d" "`

#user id and group id
uid=`id -u`
gid=`id -g`

#temp directory
tmp_dir="$TMPDIR"
test -z "$tmp_dir" -o ! -d "$tmp_dir" && tmp_dir="/tmp"

. "$includes_dir/find-lua-helper.bash.in" "$includes_dir" "$script_dir/../BashLuaHelper"
. "$bash_lua_helper" "$config" -e defaults.basedir -e defaults.chrootdir -e defaults.features -e sandbox -e profile -e dbus -b "$script_dir/sandboxer.pre.lua" -a "$script_dir/sandboxer.post.lua" -o "$profile" -o "$HOME" -o "$script_dir" -o "$curdir" -o "$config_uid" -o "$tmp_dir" -o "$tmp_dir/sandbox-$config_uid" -o "$uid" -o "$gid" -x "$@"

shift $#

test "${#cfg[@]}" = "0" && echo "can't find config storage variable populated by bash_lua_helper. bash_lua_helper failed!" && exit 1

log () {
  echo "[ $@ ]"
}

# find commander binary
commander=""
for hint in "$script_dir/commander" "$script_dir/../Build/commander"
do
  if [ -x "$hint/commander" ]; then
    commander="$hint/commander"
    break
  fi
done

test -z "$commander" && log "commander binary not found!" && exit 1

# get source-checksum
source_checksum=`2>/dev/null "$commander"`
test -z "$source_checksum" && log "failed to read correct source_checksum from commander!" && exit 1

# find executor binary
executor=""
for hint in "$HOME/.cache/sandboxer-${cfg[sandbox.setup.executor_build]}-$source_checksum" "$script_dir/executor" "$script_dir/../Build/executor"
do
  if [ -x "$hint/executor" ]; then
    executor="$hint/executor"
    break
  fi
done

test -z "$executor" && log "executor binary not found!" && exit 1

basedir="${cfg[defaults.basedir]}"

#construct control directory if not exist, needed for lock
mkdir -p "$basedir"
test "$?" != "0" && log "error creating basedir at $basedir" && exit 1

lock_entered="false"
lock_dirname="control.lock"
lock_path="$basedir/$lock_dirname"

lock_enter() {
  local nowait="$1"
  if mkdir "$lock_path" 2>/dev/null; then
    lock_entered="true"
    return 0
  else
    test ! -z "$nowait" && return 1
    log "awaiting lock release"
    while ! lock_enter "nowait"; do
      sleep 1
    done
    lock_entered="true"
    return 0
  fi
}

lock_exit() {
  if [ "$lock_entered" = "true" ]; then
    rmdir "$lock_path" 2>/dev/null
    lock_entered="false"
  fi
  true
}

teardown() {
  local status="$1"
  lock_exit
  exit $status
}

check_errors () {
  local status="$?"
  local msg="$@"
  if [ "$status" != "0" ]; then
    log "ERROR: operation finished with error code $status"
    test ! -z "$msg" && log "$msg"
    teardown "$status"
  fi
}

# extra env used by executor module ONLY
# "-post" features may use it to add extra env definitions to executor module
extra_env_set_name=()
extra_env_set_value=()
extra_env_set_cnt=0

extra_env_set_add() {
  extra_env_set_name[$extra_env_set_cnt]="$1"
  extra_env_set_value[$extra_env_set_cnt]="$2"
  extra_env_set_cnt=$((extra_env_set_cnt+1))
}

extra_env_unset=()
extra_env_unset_cnt=0

extra_env_unset_add() {
  extra_env_unset[$extra_env_unset_cnt]="$1"
  extra_env_unset_cnt=$((extra_env_unset_cnt+1))
}

#placeholder for run-profile.sh.in
wait_for_cmd_list() { true; }

#enter lock
lock_enter

#check that executor is running
###############################
if [ ! -p "$basedir/control/control.in" ] || [ ! -p "$basedir/control/control.out" ]; then

  cmd_list_bg_pid=0

  exec_cmd() {
    local cmd_path="$1"
    #protect caller's variables
    local list
    local top_cnt
    local err_code
    local fold_cnt
    #debug
    #log "exec: ${cfg[$cmd_path]}"
    eval "${cfg[$cmd_path]}"
  }

  exec_cmd_list_in_bg() {
    local list="$1"
    #debug
    #log "executing commands from $list list"
    (
    #cleanup some important defines when running custom commands to prevent possible problems
    unset -f exec_cmd_list_in_bg wait_for_cmd_list check_errors teardown lock_exit lock_enter
    unset lock_entered basedir curdir script_dir self script_file config profile config_uid uid gid bash_lua_helper cmd_list_bg_pid
    local top_cnt=1
    local err_code=0
    local exec_bg_pid_error=""
    while `check_lua_export "$list.$top_cnt"`
    do
      if [ -z "${cfg[$list.$top_cnt]}" ]; then
        local fold_cnt=1
        while `check_lua_export "$list.$top_cnt.$fold_cnt"`
        do
          exec_cmd "$list.$top_cnt.$fold_cnt"
          err_code="$?"
          test "$err_code" != "0" && exec_bg_pid_error="$list.$top_cnt.$fold_cnt" && break
          fold_cnt=$((fold_cnt+1))
        done
      else
        exec_cmd "$list.$top_cnt"
        err_code="$?"
        test "$err_code" != "0" && exec_bg_pid_error="$list.$top_cnt"
      fi
      test "$err_code" != "0" && break
      top_cnt=$((top_cnt+1))
    done
    if [ "$err_code" != "0" ]; then
      log "command $exec_bg_pid_error complete with error code $err_code"
      exit "$err_code"
    else
      exit 0
    fi
    ) &
    cmd_list_bg_pid=$!
  }

  wait_for_cmd_list() {
    if [ "$cmd_list_bg_pid" != "0" ]; then
      wait $cmd_list_bg_pid
      check_errors "command list execute failed!"
      cmd_list_bg_pid=0
    fi
  }

  # load env lists management logic for bwrap
  . "$includes_dir/sandbox-defines-bwrap.sh.in"

  log "creating sandbox"

  #chroot dir
  mkdir -p "${cfg[defaults.chrootdir]}"
  check_errors

  mkdir -p "$basedir/control"
  check_errors

  #copy executor binary
  cp "$executor" "$basedir/executor"

  #execute custom chroot construction commands
  cd "${cfg[defaults.chrootdir]}"
  check_errors

  #this will start commands execution in subshell and in background
  exec_cmd_list_in_bg "sandbox.setup.commands"

  if check_lua_export "sandbox.setup.env_whitelist"; then
    #process env_whitelist from lua config file and fillup initial env_unset list
    find_env_whitelist_match () {
      local test_val="$1"
      local top_cnt=1
      while `check_lua_export "sandbox.setup.env_whitelist.$top_cnt"`
      do
        if [ -z "${cfg[sandbox.setup.env_whitelist.$top_cnt]}" ]; then
          local fld_cnt=1
          while `check_lua_export "sandbox.setup.env_whitelist.$top_cnt.$fld_cnt"`
          do
            test "$test_val" = "${cfg[sandbox.setup.env_whitelist.$top_cnt.$fld_cnt]}" && return 0
            fld_cnt=$((fld_cnt+1))
          done
        else
          test "$test_val" = "${cfg[sandbox.setup.env_whitelist.$top_cnt]}" && return 0
        fi
        top_cnt=$((top_cnt+1))
      done
      return 1
    }
    #get current env list
    cur_env=`printenv -0 | tr -d '\n' | tr '\0' '\n' | sed -n 's|^\([^=]*\)=.*$|\1|p'`
    #iterate over list
    for test_val in $cur_env
    do
      #find match and add unset entry if not found
      find_env_whitelist_match "$test_val" && continue
      env_unset_add "$test_val"
    done
  else
    #because whitelist is disabled, fillup initial env_unset list by using sandbox.setup.env_blacklist table from lua config file
    env_unset_add_list "sandbox.setup.env_blacklist"
  fi

  #set initial env_set list (it may be altered later by "feature" scripts)
  env_set_add_list "sandbox.setup.env_set"

  #initialize parameters for selected sandboxing tool
  #(bwrap for now - it will read and apply parameters from "sandbox.bwrap")
  sandbox_init

  #add sandbox mounts for executor
  sandbox_bind_ro "$basedir/executor" "/executor/executor"
  sandbox_bind_rw "$basedir/control" "/executor/control"

  #pre-launch features
  feature_cnt=1
  while `check_lua_export "sandbox.features.$feature_cnt"`
  do
    if [ -f "$includes_dir/feature-pre-${cfg[sandbox.features.$feature_cnt]}.sh.in" ]; then
      log "preparing ${cfg[sandbox.features.$feature_cnt]} feature"
      . "$includes_dir/feature-pre-${cfg[sandbox.features.$feature_cnt]}.sh.in"
    fi
    feature_cnt=$((feature_cnt+1))
  done

  #we must wait here for completion of background command list procssing if any
  wait_for_cmd_list

  #start sandbox and launch executor module
  log "starting sandbox and master executor"
  sandbox_start

  log "waiting for control comm-channels to appear"

  comm_wait=400
  while [ ! -p "$basedir/control/control.in" ] || [ ! -p "$basedir/control/control.out" ]
  do
    if [ $comm_wait -lt 1 ]; then
      log "timeout while waiting control channels"
      teardown 1
    fi
    sleep 0.025
    comm_wait=$((comm_wait-1))
  done

fi
###############################
#check that executor is running

#post-launch features

feature_cnt=1
while `check_lua_export "sandbox.features.$feature_cnt"`
do
  if [ -f "$includes_dir/feature-post-${cfg[sandbox.features.$feature_cnt]}.sh.in" ]; then
    log "activating ${cfg[sandbox.features.$feature_cnt]} feature"
    . "$includes_dir/feature-post-${cfg[sandbox.features.$feature_cnt]}.sh.in"
  fi
  feature_cnt=$((feature_cnt+1))
done

#create new executor's sub-session inside sandbox and get new control channel name

# profile - main selected profile, may be also service profiles - dbus, pulse
exec_profile="profile"
. "$includes_dir/channel-open.sh.in"

#exit lock
lock_exit

log "running exec-profile $profile, using control channel $channel"

#start selected exec profile
. "$includes_dir/run-profile.sh.in"
