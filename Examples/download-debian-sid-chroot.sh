#!/bin/bash

# download and extract debian sid root-fs image from docker repository

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

[[ ! -d $script_dir/debian_chroot ]] || check_errors "directory $script_dir/debian_chroot already exist!"

"$script_dir/download-debian-from-docker-repo.sh" sid
