#!/bin/bash

#detection of actual script location
curdir="$PWD"
script_dir="$( cd "$( dirname "$0" )" && pwd )"
self=`basename "$0"`
[[ ! -e $script_dir/$self ]] && echo "script_dir detection failed. cannot proceed!" && exit 1
if [[ -L $script_dir/$self ]]; then
  script_file=`readlink -f "$script_dir/$self"`
  script_dir=`realpath \`dirname "$script_file"\``
fi

#load parameters
config="$1"
[[ -z $config ]] && echo "usage: sandboxer-term.sh <config file> [timeout]" && exit 1
timeout="$2"
[[ -z $timeout ]] && timeout=5

. "$script_dir/sandboxer-setup-phase-1.sh.in"

. "$includes_dir/find-lua-helper.bash.in" "$script_dir/BashLuaHelper" "$script_dir/../BashLuaHelper"
. "$bash_lua_helper" "$config" -e sandbox -e tunables -b "$script_dir/sandboxer.pre.lua" -a "$script_dir/sandboxer.post.lua" -o none -o "$HOME" -o "$script_dir" -o "$curdir" -o "$config_uid" -o "$tmp_dir" -o "$tmp_dir/sandbox-$config_uid" -o "$uid" -o "$gid"

. "$script_dir/sandboxer-setup-phase-2.sh.in"

#enter lock
lock_enter

check_sessions() {
  local el=""
  local check=0
  for el in "$control_dir"/*
  do
    [[ $el = "$control_dir/*" ]] && continue
    [[ $el =~ ^.*".in"$ || $el =~ ^.*".out"$ ]] || continue
    [[ $el =~ ^.*"/control.in"$ || $el =~ ^.*"/control.out"$ ]] && continue
    return 0
  done
  return 1
}

#check that executor is running
if [[ -p $basedir/control/control.in && -p $basedir/control/control.out ]]; then
  # load env lists management logic for bwrap
  . "$includes_dir/sandbox-defines-bwrap.sh.in"
  log "attempting to terminate all exec profles for sandbox at $basedir"
  "$commander" "$basedir/control" "control" "${cfg[sandbox.setup.security_key]}" 253 1
  check_errors
  timepass="0"
  step="0.05"
  while [[ `echo "$timepass<$timeout" | bc -q` = 1 ]]
  do
    [[ `echo "$timepass>=0.5" | bc -q` = 1 ]] && step="0.1"
    [[ `echo "$timepass>=1.0" | bc -q` = 1 ]] && step="0.25"
    [[ `echo "$timepass>=2.0" | bc -q` = 1 ]] && step="0.5"
    [[ `echo "$timepass>=5.0" | bc -q` = 1 ]] && step="1"
    sleep $step
    timepass=`echo "$timepass+$step" | bc -q`
    check_sessions || break
  done
  [[ `echo "$timepass>=$timeout" | bc -q` = 1 ]] && echo "safe termination timed out!" && exit 1
else
  log "sandbox at $basedir does not appear to be running"
fi

#exit lock
lock_exit
