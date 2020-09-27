#!/bin/bash

script_dir="$( cd "$( dirname "$0" )" && pwd )"

set -e

target="$1"
[[ -z $target ]] && echo "usage: sign.sh <target file>" && exit 1

tmp_dir="$TMPDIR"
[[ -z $tmp_dir || ! -d $tmp_dir ]] && tmp_dir="/tmp"

tmp_file=`mktemp --tmpdir="$tmp_dir" key.XXXXXXXXX`

cleanup () {
  echo "removing temporary key"
  shred -n1 "$tmp_file"
  rm "$tmp_file"
}

trap cleanup EXIT

#decrypt private key
echo "decrypting private key"
openssl aes-256-cbc -d -a -md sha512 -in "$script_dir/private.key.enc" | cat - >> "$tmp_file"
[[ ${PIPESTATUS[*]} = "0 0" ]] || false

echo "signing target file"
openssl dgst -sha512 -sign "$tmp_file" -out "$target.sign" "$target"
