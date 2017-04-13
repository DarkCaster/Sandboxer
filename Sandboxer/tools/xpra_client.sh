#!/bin/sh
base_dir="$1"
enable_tray="$2"
test -z "$enable_tray" && enable_tray=yes
test "$enable_tray" = "true" && enable_tray=yes
test "$enable_tray" = "false" && enable_tray=no
test -z "$base_dir" && exit 1
trap "{ rm -f "$base_dir/xpra-client.pid"; }" EXIT
trap "{ log \"xpra_client.sh: trap triggered, ignoring\"; }" SIGINT SIGHUP
1>"$base_dir/xpra-client.stdout" 2>"$base_dir/xpra-client.stderr" \
xpra attach --socket-dir="$base_dir/control/xpra" --compressors= --compress=0 --encoding=rgb --speed=100 --tray=$enable_tray &
xpra_pid="$!"
echo "$xpra_pid" > "$base_dir/xpra-client.pid"
wait "$xpra_pid"
exit 0
