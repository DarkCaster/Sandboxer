#!/bin/bash
#

set -e

show_usage() {
  echo "usage: extact-archive <archive file, encrypted> <base directory where archive will be extracted>"
  exit 1
}

source_file="$1"
[[ -z $source_file ]] && show_usage
[[ ! -f $source_file ]] && echo "source file not found!" && show_usage
source_file=$(readlink -f "$source_file")

target_dir="$2"
[[ -z $target_dir ]] && show_usage

mkdir -p $target_dir

pushd 1>/dev/null "$target_dir"
password=""
[[ ! -z $ARCHIVE_SECURE_KEY ]] && password="-pass env:ARCHIVE_SECURE_KEY"
openssl aes-256-cbc -a -d $password -md sha512 -in "$source_file" | xz -d | tar -xf -
popd 1>/dev/null
