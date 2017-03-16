#!/bin/bash

script_dir="$( cd "$( dirname "$0" )" && pwd )"

check_errors () {
  local status="$?"
  local msg="$@"
  if [[ $status != 0 ]]; then
    echo "ERROR: operation finished with error code $status"
    [[ ! -z $msg ]] && echo "$msg"
    exit "$status"
  fi
}

[[ ! -d $script_dir/ubuntu_chroot ]] || check_errors "directory $script_dir/ubuntu_chroot already exist!"

wget -O /tmp/ubuntu-root.tar.gz https://partner-images.canonical.com/core/precise/current/ubuntu-precise-core-cloudimg-amd64-root.tar.gz
check_errors

mkdir -p "$script_dir/ubuntu_chroot"
check_errors

cd "$script_dir/ubuntu_chroot"
check_errors

gunzip -c /tmp/ubuntu-root.tar.gz | tar xf - --no-same-owner --preserve-permissions --exclude='dev'
check_errors

mv "$script_dir/ubuntu_chroot/etc" "$script_dir/ubuntu_chroot/etc_orig"
check_errors

#remove machine-id, will be generated automatically
rm -f "$script_dir/ubuntu_chroot/etc_orig/machine-id"
check_errors

rm /tmp/ubuntu-root.tar.gz
check_errors
