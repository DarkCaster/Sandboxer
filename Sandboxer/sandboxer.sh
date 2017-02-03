#!/bin/bash

curdir="$PWD"
script_dir="$( cd "$( dirname "$0" )" && pwd )"
self=`basename "$0"`
test ! -e "$script_dir/$self" && echo "script_dir detection failed. cannot proceed!" && exit 1
script_file=`readlink "$script_dir/$self"`
test ! -z "$script_file" && script_dir=`realpath \`dirname "$script_file"\``

config="$1"
test -z "$config" && echo "usage: sandboxer.sh <config file> <exec profile> [other parameters, will be forwarded to executed app]" && exit 1
shift 1

profile="$1"
test -z "$profile" && echo "usage: sandboxer.sh <config file> <exec profile> [other parameters, will be forwarded to executed app]" && exit 1
shift 1

#generate uid for given config file
test ! -e "$config" && echo "config file not found: $config" && exit 1
config_uid=`realpath -s "$config" | md5sum -t | cut -f1 -d" "`

#user id and group id
uid=`id -u`
gid=`id -g`

. "$script_dir/find-lua-helper.bash.in"
. "$bash_lua_helper" "$config" -e sandbox -e profile -b "$script_dir/sandboxer.pre.lua" -a "$script_dir/sandboxer.post.lua" -o "$profile" -o "$HOME" -o "$script_dir" -o "$curdir" -o "$config_uid" -o "/tmp" -o "/tmp/sandbox-$config_uid" -o "$uid" -o "$gid" -x "$@"

shift $#

test "${#cfg[@]}" = "0" && echo "can't find config storage variable populated by bash_lua_helper. bash_lua_helper failed!" && exit 1

. "$script_dir/find-executor-binaries.bash.in"

log () {
 echo "[ $@ ]"
}

check_errors () {
 local status="$?"
 local msg="$@"
 if [ "$status" != "0" ]; then
  log "ERROR: operation finished with error code $status"
  test ! -z "$msg" && log "$msg"
  exit $status
 fi
}

basedir="${cfg[sandbox.setup.basedir]}"

#construct control directory
mkdir -p "$basedir"
check_errors

mkdir -p "$basedir/chroot"
check_errors

mkdir -p "$basedir/control"
check_errors

#copy executor binary
test "${cfg[sandbox.setup.static_executor]}" = "true" && cp "$executor_static" "$basedir/executor" || cp "$executor" "$basedir/executor"

#TODO default chroot construction

#execute custom chroot construction commands
cd "$basedir/chroot"
check_errors

exec_cmd() {
 local setup_cmd_cnt="$1"
 eval "${cfg[sandbox.setup.custom_commands.$setup_cmd_cnt]}"
 check_errors "custom chroot setup command block #$setup_cmd_cnt was failed!"
}

setup_cmd_cnt="1"
while `check_lua_export "sandbox.setup.custom_commands.$setup_cmd_cnt"`
do
 exec_cmd "$setup_cmd_cnt"
 setup_cmd_cnt=`expr $setup_cmd_cnt + 1`
done

#fillup main bwrap command line parameters

bwrap_params=()
bwrap_param_cnt=0

bwrap_add_param() {
 bwrap_params[$bwrap_param_cnt]="$@"
 echo "added: $@"
 bwrap_param_cnt=$((bwrap_param_cnt+1))
}

#main parameters
test "${cfg[sandbox.lockdown.user]}" = "true" && bwrap_add_param "--unshare-user"
test "${cfg[sandbox.lockdown.ipc]}" = "true" && bwrap_add_param "--unshare-ipc"
test "${cfg[sandbox.lockdown.pid]}" = "true" && bwrap_add_param "--unshare-pid"
test "${cfg[sandbox.lockdown.net]}" = "true" && bwrap_add_param "--unshare-net"
test "${cfg[sandbox.lockdown.uts]}" = "true" && bwrap_add_param "--unshare-uts"
test "${cfg[sandbox.lockdown.cgroup]}" = "true" && bwrap_add_param "--unshare-cgroup"
check_lua_export sandbox.lockdown.uid && bwrap_add_param "--uid" && bwrap_add_param "${cfg[sandbox.lockdown.uid]}"
check_lua_export sandbox.lockdown.gid && bwrap_add_param "--gid" && bwrap_add_param "${cfg[sandbox.lockdown.gid]}"
check_lua_export sandbox.lockdown.hostname && bwrap_add_param "--hostname" && bwrap_add_param "${cfg[sandbox.lockdown.hostname]}"
#TODO set\unset default env by bwrap

#append remaining parameters from sandbox.bwrap table
bwrap_cmdblk_cnt="1"
while `check_lua_export "sandbox.bwrap.$bwrap_cmdblk_cnt"`
do
 bwrap_cmd_cnt="1"
 while `check_lua_export "sandbox.bwrap.$bwrap_cmdblk_cnt.$bwrap_cmd_cnt"`
 do
  if [ "$bwrap_cmd_cnt" = "1" ]; then
   bwrap_add_param "--${cfg[sandbox.bwrap.$bwrap_cmdblk_cnt.$bwrap_cmd_cnt]}"
  else
   bwrap_add_param "${cfg[sandbox.bwrap.$bwrap_cmdblk_cnt.$bwrap_cmd_cnt]}"
  fi
  bwrap_cmd_cnt=`expr $bwrap_cmd_cnt + 1`
 done
 bwrap_cmdblk_cnt=`expr $bwrap_cmdblk_cnt + 1`
done

###eval $lua_export_list_name'=`ls -1 "'"$lua_cache_dir"'"`'

#TODO integration
#TODO features
