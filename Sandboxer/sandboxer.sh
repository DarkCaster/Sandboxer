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
[[ -z $config ]] && echo "usage: sandboxer.sh <config file> <exec profile> [other parameters, will be forwarded to executed app]" && exit 1
shift 1
profile="$1"
[[ -z $profile ]] && echo "usage: sandboxer.sh <config file> <exec profile> [other parameters, will be forwarded to executed app]" && exit 1
shift 1

. "$script_dir/sandboxer-setup-phase-1.sh.in"

. "$includes_dir/find-lua-helper.bash.in" "$script_dir/BashLuaHelper" "$script_dir/../BashLuaHelper"
. "$bash_lua_helper" "$config" -e sandbox -e profile -e dbus -e x11util -e xpra -e tunables -b "$script_dir/sandboxer.pre.lua" -a "$script_dir/sandboxer.post.lua" -o "$profile" -o "$HOME" -o "$script_dir" -o "$curdir" -o "$config_uid" -o "$tmp_dir" -o "$tmp_dir/sandbox-$config_uid" -o "$uid" -o "$gid" -x "$@"

shift $#

. "$script_dir/sandboxer-setup-phase-2.sh.in"

#enter lock
lock_enter

#check that executor is running
###############################
if [[ ! -p $basedir/control/control.in || ! -p $basedir/control/control.out ]]; then

  cmd_list_bg_pid=0

  exec_cmd() {
    local cmd_path="$1"
    #protect caller's variables
    local list
    local top_cnt
    local top_start
    local top_limit
    local err_code
    local fold_cnt
    local fold_start
    local fold_limit
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
    unset lock_entered self script_file bash_lua_helper cmd_list_bg_pid
    local top_cnt=0
    local err_code=0
    local exec_bg_pid_error=""
    local top_start=`get_lua_table_start "$list"`
    local top_limit=`get_lua_table_end "$list"`
    for ((top_cnt=top_start;top_cnt<top_limit;++top_cnt))
    do
      if ! check_lua_export "$list.$top_cnt"; then
        log "skipping empty command $list.$top_cnt"
        continue
      fi
      if [[ -z ${cfg[$list.$top_cnt]} ]]; then
        local fold_cnt=0
        local fold_start=`get_lua_table_start "$list.$top_cnt"`
        local fold_limit=`get_lua_table_end "$list.$top_cnt"`
        for ((fold_cnt=fold_start;fold_cnt<fold_limit;++fold_cnt))
        do
          if ! check_lua_export "$list.$top_cnt.$fold_cnt"; then
            log "skipping empty command $list.$top_cnt.$fold_cnt"
            continue
          fi
          exec_cmd "$list.$top_cnt.$fold_cnt"
          err_code="$?"
          [[ $err_code != 0 ]] && exec_bg_pid_error="$list.$top_cnt.$fold_cnt" && break
        done
      else
        exec_cmd "$list.$top_cnt"
        err_code="$?"
        [[ $err_code != 0 ]] && exec_bg_pid_error="$list.$top_cnt"
      fi
      [[ $err_code != 0 ]] && break
    done
    if [[ $err_code != 0 ]]; then
      log "command $exec_bg_pid_error complete with error code $err_code"
      exit "$err_code"
    else
      exit 0
    fi
    ) &
    cmd_list_bg_pid=$!
  }

  wait_for_cmd_list() {
    if [[ $cmd_list_bg_pid != 0 ]]; then
      wait $cmd_list_bg_pid
      check_errors "command list execute failed!"
      cmd_list_bg_pid=0
    fi
  }

  # load env lists management logic for bwrap
  . "$includes_dir/sandbox-defines-bwrap.sh.in"

  log "creating sandbox"

  #chroot dir
  mkdir -p "${cfg[tunables.chrootdir]}"
  check_errors

  mkdir -p "$basedir/control"
  check_errors

  mkdir -p "$basedir/extra"
  check_errors

  #copy executor binary
  cp "$executor" "$basedir/executor"

  #execute custom chroot construction commands
  cd "${cfg[tunables.chrootdir]}"
  check_errors

  #this will start commands execution in subshell and in background
  exec_cmd_list_in_bg "sandbox.setup.commands"

  if check_lua_export "sandbox.setup.env_whitelist"; then
    #process env_whitelist from lua config file and fillup initial env_unset list
    find_env_whitelist_match () {
      local test_val="$1"
      local top_cnt=0
      local top_cnt_min=`get_lua_table_start "sandbox.setup.env_whitelist"`
      local top_cnt_max=`get_lua_table_end "sandbox.setup.env_whitelist"`
      for ((top_cnt=top_cnt_min;top_cnt<top_cnt_max;++top_cnt))
      do
        if [[ -z ${cfg[sandbox.setup.env_whitelist.$top_cnt]} ]]; then
          local fld_cnt=0
          local fld_cnt_min=`get_lua_table_start "sandbox.setup.env_whitelist.$top_cnt"`
          local fld_cnt_max=`get_lua_table_end "sandbox.setup.env_whitelist.$top_cnt"`
          for ((fld_cnt=fld_cnt_min;fld_cnt<fld_cnt_max;++fld_cnt))
          do
            [[ $test_val = ${cfg[sandbox.setup.env_whitelist.$top_cnt.$fld_cnt]} ]] && return 0
          done
        else
          [[ $test_val = ${cfg[sandbox.setup.env_whitelist.$top_cnt]} ]] && return 0
        fi
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
  sandbox_bind_ro "$basedir/extra" "/executor/extra"

  extra_dirs_cleanup=()
  extra_dirs_cleanup_cnt=0

  add_extra_dir_cleanup() {
    extra_dirs_cleanup[$extra_dirs_cleanup_cnt]="$1"
    extra_dirs_cleanup_cnt=$((extra_dirs_cleanup_cnt+1))
  }

  #pre-launch features
  feature_cnt_min=`get_lua_table_start "sandbox.features"`
  feature_cnt_max=`get_lua_table_end "sandbox.features"`
  for ((feature_cnt=feature_cnt_min;feature_cnt<feature_cnt_max;++feature_cnt))
  do
    if [[ -f $includes_dir/feature-pre-${cfg[sandbox.features.$feature_cnt]}.sh.in ]]; then
      log "preparing ${cfg[sandbox.features.$feature_cnt]} feature"
      . "$includes_dir/feature-pre-${cfg[sandbox.features.$feature_cnt]}.sh.in"
    fi
  done

  #we must wait here for completion of background command list procssing if any
  wait_for_cmd_list

  #start sandbox and launch executor module
  log "starting sandbox and master executor"
  sandbox_start

  log "waiting for control comm-channels to appear"

  comm_wait=400
  while [[ ! -p $basedir/control/control.in || ! -p $basedir/control/control.out ]]
  do
    if [[ $comm_wait -lt 1 ]]; then
      log "timeout while waiting control channels"
      teardown 1
    fi
    sleep 0.025
    comm_wait=$((comm_wait-1))
  done

fi
###############################
#check that executor is running

# extra env used by slave executor module ONLY
# "-post" features may use it to add extra env definitions to slave executor module
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

#post-launch features
watchdog_profiles=()
watchdog_profiles_cnt=0

add_watchdog_profile() {
  watchdog_profiles[$watchdog_profiles_cnt]="-p"
  watchdog_profiles_cnt=$((watchdog_profiles_cnt+1))
  watchdog_profiles[$watchdog_profiles_cnt]="$1"
  watchdog_profiles_cnt=$((watchdog_profiles_cnt+1))
}

post_feature_failed=0
feature_cnt_min=`get_lua_table_start "sandbox.features"`
feature_cnt_max=`get_lua_table_end "sandbox.features"`
for ((feature_cnt=feature_cnt_min;feature_cnt<feature_cnt_max;++feature_cnt))
do
  if [[ -f $includes_dir/feature-post-${cfg[sandbox.features.$feature_cnt]}.sh.in ]]; then
    log "activating ${cfg[sandbox.features.$feature_cnt]} feature"
    . "$includes_dir/feature-post-${cfg[sandbox.features.$feature_cnt]}.sh.in"
  fi
  [[ $post_feature_failed != 0 ]] && break
done

if [[ $post_feature_failed = 0 ]]; then
  # create new executor's sub-session inside sandbox and get new control channel name
  # profile - main selected profile
  exec_profile="profile"
  . "$includes_dir/channel-open.sh.in"
fi

# run watchdog script if we have started any features
if [[ $watchdog_profiles_cnt != 0 ]]; then
  "$tools_dir/watchdog.sh" -b "$basedir/control" -s "$lock_path" -w "$basedir/watchdog.lock" -l "$basedir/watchdog.log" -c "$commander" -k "${cfg[sandbox.setup.security_key]}" ${watchdog_profiles[@]} &
fi

[[ $post_feature_failed != 0 ]] && log "feature's -post script was failed, cannot proceed!" && teardown 1

#exit lock
lock_exit

log "running exec-profile $profile, using control channel $channel"

#start selected exec profile
. "$includes_dir/run-profile.sh.in"
