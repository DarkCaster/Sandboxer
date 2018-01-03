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
[[ -z $config ]] && echo "usage: sandboxer-term.sh <config file>" && exit 1

. "$script_dir/sandboxer-setup-phase-1.sh.in"

. "$includes_dir/find-lua-helper.bash.in" "$script_dir/BashLuaHelper" "$script_dir/../BashLuaHelper"
. "$bash_lua_helper" "$config" -e sandbox -e tunables -b "$script_dir/sandboxer.pre.lua" -a "$script_dir/sandboxer.post.lua" -o none -o "$HOME" -o "$script_dir" -o "$curdir" -o "$config_uid" -o "$tmp_dir" -o "$tmp_dir/sandbox-$config_uid" -o "$uid" -o "$gid"

. "$script_dir/sandboxer-setup-phase-2.sh.in"

#enter lock
lock_enter

#check that executor is running
if [[ ! -p $basedir/control/control.in || ! -p $basedir/control/control.out ]]; then
  # load env lists management logic for bwrap
  . "$includes_dir/sandbox-defines-bwrap.sh.in"
  log "attempting to terminate all exec profles for sandbox with $uid"
  "$commander" "$basedir/control" "control" "${cfg[sandbox.setup.security_key]}" 253 1
  check_errors
else
  log "sandbox with $uid does not appear to be running"
fi

#exit lock
lock_exit
