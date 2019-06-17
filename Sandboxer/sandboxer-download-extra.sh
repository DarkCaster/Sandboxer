#!/bin/bash

# helper script, that will check, download and verify precompiled helper utilities
# for use with different types of external root-fs sandboxes
# usage: sandboxer-download-extra.sh <space separated targets list>

dl_base="https://github.com/DarkCaster/Sandboxer/releases/download/external-binaries"

#detection of actual script location
curdir="$PWD"
script_dir="$( cd "$( dirname "$0" )" && pwd )"
self=`basename "$0"`
[[ ! -e $script_dir/$self ]] && echo "script_dir detection failed. cannot proceed!" && exit 1
if [[ -L $script_dir/$self ]]; then
  script_file=`readlink -f "$script_dir/$self"`
  script_dir=`realpath \`dirname "$script_file"\``
fi

set -e

tmp_dir="$TMPDIR"
[[ -z $tmp_dir || ! -d $tmp_dir ]] && tmp_dir="/tmp"

targets="$1"
[[ -z $targets ]] && targets=( debian-9-i386 debian-9-amd64 debian-10-i386 debian-10-amd64 ubuntu-18.04-amd64 )

download () {
  echo -n "*** trying $1 ..."
  if ! ( cd "$tmp_dir" && wget -q "$1.tar.xz" ); then
    echo " failed."
    return 1
  else
    echo " ok."
  fi

  echo -n "*** trying $1.tar.xz.sign ..."
  if ! ( cd "$tmp_dir" && wget -q "$1.tar.xz.sign" ); then
    echo " failed."
    return 1
  else
    echo " ok."
  fi
}

verify () {
  "$script_dir/signing/verify.sh" "$tmp_dir/$1.tar.xz" || return 1
}

extract () {
  echo "extracting $1.tar.xz to $HOME/.cache/sandboxer"
  mkdir -p "$HOME/.cache/sandboxer"
  rm -rf "$HOME/.cache/sandboxer/$1"
  ( cd "$HOME/.cache/sandboxer" && xz -c -d "$tmp_dir/$1.tar.xz" | tar xf - )
}

cleanup () {
  rm -f "$tmp_dir/$1.tar.xz"
  rm -f "$tmp_dir/$1.tar.xz.sign"
}

commander=""
for hint in "$script_dir/commander" "$script_dir/../Build/commander"
do
  if [[ -x $hint/commander ]]; then
    commander="$hint/commander"
    break
  fi
done

[[ -z $commander ]] && echo "commander binary not found!" && exit 1
checksum=`2>/dev/null "$commander" || true`

for target in "${targets[@]}"
do
  file="executor-$target-$checksum"
  cleanup "$file"
  ( download "$dl_base/$file" && verify "$file" && extract "$file" ) || true
  cleanup "$file"
  file="extra-binaries-$target"
  cleanup "$file"
  ( download "$dl_base/$file" && verify "$file" && extract "$file" ) || true
  cleanup "$file"
done
