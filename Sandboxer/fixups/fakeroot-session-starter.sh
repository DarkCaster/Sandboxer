#!/bin/sh

fakeroot_dist="$1"
shift 1
fakeroot_version="$1"
shift 1
fakeroot_arch="$1"
shift 1
command="$1"
shift 1

fakeroot_search_dir="/fixups"

show_usage() {
  echo "usage: fakeroot-session-starter.sh <dist> <version> <arch> <command> [command arguments]"
  exit 1
}

test -z "$fakeroot_dist" -o -z "$command" && show_usage
test -z "$fakeroot_version" -o -z "$command" && show_usage
test -z "$fakeroot_arch" -o -z "$command" && show_usage

fakeroot=""
for hint in "$fakeroot_search_dir/fakeroot-$fakeroot_dist-$fakeroot_version-$fakeroot_arch" "$fakeroot_search_dir/fakeroot-$fakeroot_dist-$fakeroot_arch" "$fakeroot_search_dir/fakeroot-host"
do
  echo -n "searching for fakeroot utility at $hint dir ... "
  if [ -x "$hint/fakeroot" ]; then
    fakeroot="$hint/fakeroot"
    echo "found!"
    break
  else
    echo "not found..."
  fi
done

test -z "$fakeroot" && echo "usable fakeroot binary not found! cannot proceed..." && exit 1

# In some host/sandbox environments fakeroot utility refuse to work on the first run, so we will use this small and dirty hack for now.
2>/dev/null "$fakeroot" -- /bin/true

#locking

lock_path="/root/fakeroot.lock"
lock_entered="false"

lock_enter() {
  if mkdir "$lock_path" 2>/dev/null; then
    lock_entered="true"
  else
    lock_entered="false"
  fi
}

lock_exit() {
  if test "$lock_entered" = "true"; then
    rmdir "$lock_path" 2>/dev/null
    lock_entered="false"
  fi
}

fakeroot_db="/root/fakeroot.db"

#only one instance of fakeroot may access permissions database, so use "locking"
lock_enter

if [ "$lock_entered" != "true" ]; then
  echo "WARNING: another fakeroot instance running in this sandbox, do not attempt to use permissions database"
  echo "NOTE: if you sure that no other fakeroot instances running, you may manually remove $lock_path dir inside chroot..."
  "$fakeroot" -- "$command" "$@"
elif [ -f "$fakeroot_db" ]; then
  echo "using permissions database at $fakeroot_db"
  "$fakeroot" -i "$fakeroot_db" -s "$fakeroot_db" -- "$command" "$@"
else
  echo "creating new permissions database at $fakeroot_db"
  "$fakeroot" -s "$fakeroot_db" -- "$command" "$@"
fi

ec="$?"

lock_exit

echo "fakeroot utility exit code $ec, fakeroot-session-starter shuting down"
exit $ec
