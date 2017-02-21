#!/bin/bash

script_dir="$( cd "$( dirname "$0" )" && pwd )"

check_errors () {
 local status="$?"
 local msg="$@"
 if [ "$status" != "0" ]; then
  echo "ERROR: operation finished with error code $status"
  test ! -z "$msg" && echo "$msg"
  exit "$status"
 fi
}

test ! -d "$script_dir/ubuntu_yakkety_chroot" || check_errors "directory $script_dir/ubuntu_yakkety_chroot already exist!"

wget -O /tmp/ubuntu-root.tar.gz https://partner-images.canonical.com/core/yakkety/current/ubuntu-yakkety-core-cloudimg-amd64-root.tar.gz
check_errors

mkdir -p "$script_dir/ubuntu_yakkety_chroot"
check_errors

cd "$script_dir/ubuntu_yakkety_chroot"
check_errors

gunzip -c /tmp/ubuntu-root.tar.gz | tar xf - --no-same-owner --preserve-permissions --exclude='dev'
check_errors

rm /tmp/ubuntu-root.tar.gz
check_errors
