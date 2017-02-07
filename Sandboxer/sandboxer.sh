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
. "$bash_lua_helper" "$config" -e defaults.basedir -e defaults.features -e sandbox -e profile -e dbus -b "$script_dir/sandboxer.pre.lua" -a "$script_dir/sandboxer.post.lua" -o "$profile" -o "$HOME" -o "$script_dir" -o "$curdir" -o "$config_uid" -o "/tmp" -o "/tmp/sandbox-$config_uid" -o "$uid" -o "$gid" -x "$@"

shift $#

test "${#cfg[@]}" = "0" && echo "can't find config storage variable populated by bash_lua_helper. bash_lua_helper failed!" && exit 1

. "$script_dir/find-executor-binaries.bash.in"

log () {
 echo "[ $@ ]"
}

basedir="${cfg[defaults.basedir]}"

#construct control directory if not exist, needed for lock
mkdir -p "$basedir"
test "$?" != "0" && log "error creating basedir at $basedir" && exit 1

lock_entered="false"

lock_enter() {
 local nowait="$1"
 if mkdir "$basedir/executor.lock" 2>/dev/null; then
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
  rmdir "$basedir/executor.lock" 2>/dev/null
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

#enter lock
lock_enter

#check that executor is running
###############################
if [ ! -p "$basedir/control/control.in" ] || [ ! -p "$basedir/control/control.out" ]; then

log "creating sandbox"

#if executor is not running
mkdir -p "$basedir/chroot"
check_errors

mkdir -p "$basedir/control"
check_errors

#copy executor binary
test "${cfg[sandbox.setup.static_executor]}" = "true" && cp "$executor_static" "$basedir/executor" || cp "$executor" "$basedir/executor"

#TODO default chroot construction

exec_cmd() {
 local cmd_path="$1"
 #debug
 #echo "exec: ${cfg[$cmd_path]}"
 eval "${cfg[$cmd_path]}"
 check_errors "chroot setup command $cmd_path was failed!"
}

exec_process_cmd_list() {
 local list="$1"
 local cnt=1
 while `check_lua_export "$list.$cnt"`
 do
  exec_cmd "$list.$cnt"
  cnt=$((cnt+1))
 done
}

exec_process_two_level_cmd_list() {
 local list="$1"
 local cnt=1
 while `check_lua_export "$list.$cnt"`
 do
  exec_process_cmd_list "$list.$cnt"
  cnt=$((cnt+1))
 done
}

#execute custom chroot construction commands
cd "$basedir/chroot"
check_errors

exec_process_two_level_cmd_list "sandbox.setup.custom_commands"

#fillup main bwrap command line parameters

bwrap_params=()
bwrap_param_cnt=0

bwrap_add_param() {
 bwrap_params[$bwrap_param_cnt]="$@"
 #debug
 #echo "added: $@"
 bwrap_param_cnt=$((bwrap_param_cnt+1))
}

#main parameters
bwrap_add_param "--new-session"
test "${cfg[sandbox.lockdown.user]}" = "true" && bwrap_add_param "--unshare-user"
test "${cfg[sandbox.lockdown.ipc]}" = "true" && bwrap_add_param "--unshare-ipc"
test "${cfg[sandbox.lockdown.pid]}" = "true" && bwrap_add_param "--unshare-pid"
test "${cfg[sandbox.lockdown.net]}" = "true" && bwrap_add_param "--unshare-net"
test "${cfg[sandbox.lockdown.uts]}" = "true" && bwrap_add_param "--unshare-uts"
test "${cfg[sandbox.lockdown.cgroup]}" = "true" && bwrap_add_param "--unshare-cgroup"
check_lua_export sandbox.lockdown.uid && bwrap_add_param "--uid" && bwrap_add_param "${cfg[sandbox.lockdown.uid]}"
check_lua_export sandbox.lockdown.gid && bwrap_add_param "--gid" && bwrap_add_param "${cfg[sandbox.lockdown.gid]}"
check_lua_export sandbox.lockdown.hostname && bwrap_add_param "--hostname" && bwrap_add_param "${cfg[sandbox.lockdown.hostname]}"

bwrap_env_set_unset() {
 local env_op="$1"
 local env_table="$2"
 local env_blk_cnt=1
 while `check_lua_export "$env_table.$env_blk_cnt"`
 do
  local env_cmd_cnt=1
  while `check_lua_export "$env_table.$env_blk_cnt.$env_cmd_cnt"`
  do
   if [ "$env_op" = "unset" ]; then
    bwrap_add_param "--unsetenv"
    bwrap_add_param "${cfg[$env_table.$env_blk_cnt.$env_cmd_cnt]}"
   elif [ "$env_op" = "set" ]; then
    bwrap_add_param "--setenv"
    bwrap_add_param "${cfg[$env_table.$env_blk_cnt.$env_cmd_cnt.1]}"
    bwrap_add_param "${cfg[$env_table.$env_blk_cnt.$env_cmd_cnt.2]}"
   else
	log "internal error: unsupported env operation"
    teardown 1
   fi
   env_cmd_cnt=$((env_cmd_cnt+1))
  done
  env_blk_cnt=$((env_blk_cnt+1))
 done
}

#TODO env white list

#unset default env by bwrap
bwrap_env_set_unset "unset" "sandbox.setup.env_blacklist"

#set default env by bwrap
bwrap_env_set_unset "set" "sandbox.setup.env_set"

bwrap_process_params_list() {
 local list="$1"
 local cnt=1
 while `check_lua_export "$list.$cnt"`
 do
  if [ "$cnt" = "1" ]; then
   bwrap_add_param "--${cfg[$list.$cnt]}"
  else
   bwrap_add_param "${cfg[$list.$cnt]}"
  fi
  cnt=$((cnt+1))
 done
}

bwrap_process_two_level_params_list() {
 local list="$1"
 local cnt=1
 while `check_lua_export "$list.$cnt"`
 do
  bwrap_process_params_list "$list.$cnt"
  cnt=$((cnt+1))
 done
}

#append remaining parameters from sandbox.bwrap table
bwrap_process_two_level_params_list "sandbox.bwrap"

#append parameters to mount executor binary and control directory
bwrap_add_param "--dir"
bwrap_add_param "/executor"
bwrap_add_param "--ro-bind"
bwrap_add_param "$basedir/executor"
bwrap_add_param "/executor/executor"
bwrap_add_param "--bind"
bwrap_add_param "$basedir/control"
bwrap_add_param "/executor/control"

#pre launch features

if [ "${cfg[sandbox.features.dbus]}" = "true" ]; then
. "$script_dir/feature-pre-dbus.sh.in"
fi

log "starting new master executor"

#run bwrap and start executor
&>"$basedir/control/bwrap.log" bwrap "${bwrap_params[@]}" "/executor/executor" 0 1 "/executor/control" "control" "${cfg[sandbox.setup.security_key]}" &

log "waiting for control comm-channels to appear"

comm_wait=200
while [ ! -p "$basedir/control/control.in" ] || [ ! -p "$basedir/control/control.out" ]
do
 if [ $comm_wait -lt 1 ]; then
  log "timeout while waiting control channels"
  teardown 1
 fi
 sleep 0.05
 comm_wait=$((comm_wait-1))
done

fi
###############################
#check that executor is running

#post launch features

if [ "${cfg[sandbox.features.dbus]}" = "true" ]; then
. "$script_dir/feature-post-dbus.sh.in"
fi

#create new executor's sub-session inside sandbox and get new control channel name

# profile - main selected profile, may be also service profiles - dbus, pulse
exec_profile="profile"
. "$script_dir/channel-open.sh.in"

#exit lock
lock_exit

log "running exec-profile $profile, using control channel $channel"

#start selected exec profile
. "$script_dir/run-profile.sh.in"

