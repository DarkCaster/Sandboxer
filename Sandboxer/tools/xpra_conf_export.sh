#!/bin/sh

target="$@"
test -z "$target" && target="/executor/control/xpra/xpra_conf.out"

export > "$target.env"
echo "DISPLAY=$DISPLAY:EOL" > "$target"
