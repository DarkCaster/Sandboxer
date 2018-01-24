#!/bin/dash

# usage: bwrap_launcher.sh
#         <cleanup basedir and other directories - true\false>
#         <basedir>
#         <additional dir to cleanup on exit> <additional dir> ...
#         -- - end of launcher script parameters
#         <bwrap commandline, including bwrap command>

cleanup="$1"
logfile="$2"
lock_dirname="$3"
basedir="$4"
shift 4

extra_paths_counter=0

while test "$1" != "--"
do
  if test ! -z "$1"; then
    extra_paths_counter=`expr $extra_paths_counter + 1`
    eval 'extra_path_'"$extra_paths_counter"'="'"$1"'"'
  fi
  shift 1
done
shift 1

lock_path="$basedir/$lock_dirname"
lock_entered="false"
nowait=""

log() {
  echo "$@" >> "$basedir/$logfile"
}

error() {
  echo "$@" >> "$basedir/$logfile"
  1>&2 echo "$@"
}

cat_error_to_logfile() {
  cat "$@" >> "$basedir/$logfile"
  1>&2 cat "$@"
}

log "bwrap_launcher.sh startup"
log "cleanup=$cleanup" # debug
log "basedir=$basedir" # debug
log "lock_dirname=$lock_dirname" # debug
log "extra_paths_counter=$extra_paths_counter" # debug

nohup_bin=`2>/dev/null which nohup`
test -z "$nohup_bin" && error "nohup binary from coreutils package not found! cannot proceed!" && exit 1

check_sessions() {
  for session in "$basedir/control/"*.in "$basedir/control/"*.out
  do
    test "$session" = "$basedir/control/*.in" && continue
    test "$session" = "$basedir/control/*.out" && continue
    return 0
  done
  return 1
}

lock_enter() {
  nowait="$1"
  if mkdir "$lock_path" 2>/dev/null; then
    lock_entered="true"
    return 0
  else
    test ! -z "$nowait" && return 1
    log "awaiting lock release" # debug
    while ! lock_enter "nowait"; do
      sleep 1
    done
    return 0
  fi
}

lock_exit() {
  if test "$lock_entered" = "true"; then
    rmdir "$lock_path" 2>/dev/null
    lock_entered="false"
  fi
  return 0
}

trap "{ log \"bwrap_launcher.sh: trap triggered, ignoring\"; }" INT HUP TERM

log "launching bwrap with command line: $@"
0</dev/null 1>"$basedir/bwrap.log" 2>&1 "$nohup_bin" "$@"

err_code="$?"
if [ "$err_code" != "0" ]; then
  error "bwrap failed with error code $err_code, bwrap.log output:"
  cat_error_to_logfile "$basedir/bwrap.log"
  touch "$basedir/sandbox.failed"
  exit 1
fi

#below is a cleanup-on-exit logic that may be activated when bwrap is complete
test "$cleanup" != "true" && exit 0

lock_enter

if check_sessions; then
  lock_exit
  error "bwrap_launcher.sh cannot perform cleanup, because some other sessions currently running in sandbox"
  exit 1
fi

for ext_el in `seq 1 $extra_paths_counter`
do
  eval 'target_path="$extra_path_'"$ext_el"'"'
  log "removing extra directory $target_path" # debug
  rm -rf "$target_path"
done

cd "$basedir"

for el in *
do
  test "$el" = "$lock_dirname" -o "$el" = "bwrap.log" -o "$el" = "$logfile" && log "skipping $el" && continue
  log "removing $el" # debug
  rm -rf "$el"
done

lock_exit

log "cleanup complete" # debug
exit 0
