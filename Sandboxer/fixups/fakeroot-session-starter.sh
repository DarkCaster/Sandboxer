#!/bin/sh

show_usage() {
  echo "usage: fakeroot-session-starter.sh <true|false - use perm.db> <util search suffix> <util search suffix> ... -- <command> [arguments]"
  exit 1
}

use_db="$1"
test -z "$use_db" && show_usage
[ "$use_db" != "true" ] && [ "$use_db" != "false" ] && show_usage

shift 1

fakeroot_search_dir="/fixups"
fakeroot=""

suffix="$1"
test -z "$suffix" && show_usage
while [ "$suffix" != "--" ]; do
  if [ -z "$fakeroot" ]; then
    search_dir="$fakeroot_search_dir/fakeroot-$suffix"
    echo -n "searching for fakeroot utility at $search_dir dir ... "
    if [ -x "$search_dir/fakeroot" ]; then
      fakeroot="$search_dir/fakeroot"
      echo "found!"
    else
      echo "not found."
    fi
  fi
  shift 1
  suffix="$1"
  test -z "$suffix" && show_usage
done

shift 1

command="$1"
test -z "$command" && show_usage

shift 1

if [ -z "$fakeroot" ]; then
  if [ -x "$fakeroot_search_dir/fakeroot-host/fakeroot" ]; then
      fakeroot="$fakeroot_search_dir/fakeroot-host/fakeroot"
      echo "using fallback fakeroot util at $fakeroot"
    else
      echo "usable fakeroot binary not found! cannot proceed..." && exit 1
    fi
fi

# In some host/sandbox environments fakeroot utility refuse to work on the first run, so we will use this small and dirty hack for now.
2>/dev/null "$fakeroot" -- /bin/true

#locking

lock_path="/root/.fakeroot.lock"
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

fakeroot_db="/root/.fakeroot.db"

#only one instance of fakeroot may access permissions database, so use "locking"
lock_enter

if [ "$use_db" = "false" ]; then
  echo "NOTE: not using permissions database"
  "$fakeroot" -- "$command" "$@"
elif [ "$lock_entered" != "true" ]; then
  echo "WARNING: another fakeroot instance running in this sandbox, do not attempt to use permissions database"
  echo "NOTE: if you sure that no other fakeroot instances running, you may manually remove $lock_path dir inside chroot..."
  "$fakeroot" -- "$command" "$@"
elif [ -f "$fakeroot_db" ]; then
  echo "loading permissions database at $fakeroot_db, this may take some time to complete"
  echo "NOTE: saving permissions-list on exit may take a long time to complete!"
  "$fakeroot" -i "$fakeroot_db" -s "$fakeroot_db" -- "$command" "$@"
else
  echo "creating new permissions database at $fakeroot_db"
  echo "NOTE: saving permissions-list on exit may take a long time to complete!"
  "$fakeroot" -s "$fakeroot_db" -- "$command" "$@"
fi

ec="$?"

lock_exit

echo "fakeroot utility exit code $ec, fakeroot-session-starter shuting down"
exit $ec
