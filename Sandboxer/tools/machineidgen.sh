#!/bin/bash

check_errors () {
  local status="$?"
  local msg="$@"
  if [ "$status" != "0" ]; then
    echo "machineidgen.sh: operation finished with error code $status"
    test ! -z "$msg" && echo "$msg"
    exit "$status"
  fi
}

tmpdir="$1"
dest="$2"
shift 2

tmpfile="$tmpdir/machineidgen"
echo -n "" > "$tmpfile"
check_errors "failed create $tmpfile file"

for src in "$@"
do
  md5sum -b "$src" | cut -f1 -d' ' >> "$tmpfile"
  check_errors "failed to compute checksum for $src file"
done

md5sum -b "$tmpfile" | cut -f1 -d' ' > "$dest"
check_errors "failed to generate machine-id file at $dest"
