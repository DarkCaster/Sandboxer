#!/bin/dash
base_dir="$1"
enable_tray="$2"
ipc_file="$3"
test -z "$enable_tray" && enable_tray=yes
test "$enable_tray" = "true" && enable_tray=yes
test "$enable_tray" = "false" && enable_tray=no
test -z "$base_dir" && exit 1
trap "{ rm -f "$base_dir/xpra-client.pid"; }" EXIT
trap "{ echo \"xpra_client.sh: trap triggered, ignoring\"; }" INT HUP
if test -z "$ipc_file"; then
  1>"$base_dir/xpra-client.stdout" 2>"$base_dir/xpra-client.stderr" \
  xpra attach --socket-dir="$base_dir/control/xpra" --pings=no --compressors= --compress=0 --encoding=rgb --speed=100 --min-speed=100 --quality=100 --min-quality=100 --tray=$enable_tray &
else
  1>"$base_dir/xpra-client.stdout" 2>"$base_dir/xpra-client.stderr" \
  xpra attach --socket-dir="$base_dir/control/xpra" --mmap="$ipc_file" --pings=no --compressors= --compress=0 --encoding=rgb --speed=100 --min-speed=100 --quality=100 --min-quality=100 --tray=$enable_tray &
fi
xpra_pid="$!"
echo "$xpra_pid" > "$base_dir/xpra-client.pid"
wait "$xpra_pid"
exit 0
