#!/bin/sh

control_dir="$1"
enable_tray="$2"

test -z "$enable_tray" && enable_tray=yes
test "$enable_tray" = "true" && enable_tray=yes
test "$enable_tray" = "false" && enable_tray=no

test -z "$control_dir" && exit 1

trap "{ rm -f "$control_dir/xpra/client.pid"; }" EXIT

trap "{ log \"xpra_client.sh: trap triggered, ignoring\"; }" SIGINT SIGHUP

1>"$control_dir/xpra/client.stdout" 2>"$control_dir/xpra/client.stderr" \
xpra attach --socket-dir="$control_dir/xpra" --compressors= --compress=0 --encoding=rgb --speed=100 --tray=$enable_tray &
xpra_pid="$!"
echo "$xpra_pid" > "$control_dir/xpra/client.pid"
wait "$xpra_pid"
exit 0
