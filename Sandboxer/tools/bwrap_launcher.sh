#!/bin/dash

# usage: bwrap_launcher.sh
#         <cleanup basedir and other directories - true\false>
#         <basedir>
#         <additional dir to cleanup on exit> <additional dir> ...
#         -- - end of launcher script parameters
#         <parameters for bwrap>

cleanup="$1"
lock_dirname="$2"
basedir="$3"
shift 3

extra_paths_counter=0

while test "$1" != "--" -a "$1" != ""
do
  extra_paths_counter=`expr $extra_paths_counter + 1`
  eval 'extra_path_'"$extra_paths_counter"'="'"$1"'"'
  shift 1
done
shift 1

lock_path="$basedir/$lock_dirname"
lock_entered="false"
nowait=""

echo "cleanup=$cleanup" # debug
echo "lock_dirname=$lock_dirname" # debug
echo "basedir=$basedir" # debug
echo "extra_paths_counter=$extra_paths_counter" # debug

check_sessions() {
  test `ls -1 "$basedir/control" | grep -E "(^.*\.in\$)|(^.*\.out\$)" | wc -l` != "0" && return 0
  return 1
}

lock_enter() {
  nowait="$1"
  if mkdir "$lock_path" 2>/dev/null; then
    lock_entered="true"
    return 0
  else
    test ! -z "$nowait" && return 1
    echo "awaiting lock release" # debug
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

trap "{ echo \"bwrap_launcher.sh: trap triggered, ignoring\"; }" INT HUP

>"$basedir/bwrap.log" 2>&1 bwrap "$@"

err_code="$?"
test "$err_code" != "0" && echo "bwrap failed with error code $err_code, bwrap.log output:" && cat "$basedir/bwrap.log" && exit 1

#below is a cleanup-on-exit logic that may be activated when bwrap is complete
test "$cleanup" != "true" && exit 0

lock_enter

if check_sessions; then
  lock_exit
  echo "bwrap_launcher.sh cannot perform cleanup, because some other sessions currently running in sandbox"
  exit 1
fi

for ext_el in `seq 1 $extra_paths_counter`
do
  eval 'target_path="$extra_path_'"$ext_el"'"'
  echo "removing directory $target_path" # debug
  rm -rf "$target_path"
done

cd "$basedir"

for el in *
do
  test "$el" = "$lock_dirname" && continue
  echo "removing $el" # debug
  rm -rf "$el"
done

lock_exit

echo "cleanup complete" # debug
exit 0
