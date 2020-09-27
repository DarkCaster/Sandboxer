#!/bin/bash
#

set -e

show_usage() {
  echo "usage: create-archive <source-dir, will be root of archive> <target archive file, encrypted>"
  exit 1
}

source_dir="$1"
[[ -z $source_dir ]] && show_usage
[[ ! -d $source_dir ]] && echo "source dir not found!" && show_usage

target_file="$2"
[[ -z $target_file ]] && show_usage
target_file=$(readlink -f "$target_file")

base=$(dirname "$source_dir")
src=$(basename "$source_dir")

rm -fv "$target_file"

pushd 1>/dev/null "$base"
tar --group=0 --owner=0 -c "$src" | xz -9e | openssl aes-256-cbc -a -e -salt -md sha512 -out "$target_file"
popd 1>/dev/null
