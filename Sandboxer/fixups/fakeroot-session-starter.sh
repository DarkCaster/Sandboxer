#!/bin/sh

fakeroot_build="$1"
shift 1
command="$1"
shift 1

fakeroot_search_dir="/fixups"

show_usage() {
  echo "usage: fakeroot-session-starter.sh <fakeroot build> <command> [command arguments]"
  exit 1
}

test -z "$fakeroot_build" -o -z "$command" && show_usage

fakeroot=""
echo "fakeroot-session-starter: trying to detect requested build '$fakeroot_build' of fakeroot utility"
for hint in "$fakeroot_search_dir/fakeroot-$fakeroot_build" "$fakeroot_search_dir/fakeroot-host" "$fakeroot_search_dir/fakeroot-fallback"
do
  if [ -x "$hint/fakeroot" ]; then
    fakeroot="$hint/fakeroot"
    echo "fakeroot-session-starter: using fakeroot binary at $hint directory"
    break
  else
    echo "fakeroot-session-starter: probe for fakeroot at $hint directory failed! you should try to download extra prebuilt fakeroot binaries by running sandboxer-download-extra.sh"
  fi
done

test -z "$fakeroot" && echo "fakeroot binaries not found! cannot proceed." && exit 1

# In some host/sandbox environments fakeroot utility refuse to work on the first run, so we will use this small and dirty hack for now.
2>/dev/null "$fakeroot" -- /bin/true
"$fakeroot" -- "$command" "$@"

ec="$?"
echo "fakeroot-session-starter: fakeroot utility exit with code $ec, fakeroot-session-starter shuting down"
exit $ec
