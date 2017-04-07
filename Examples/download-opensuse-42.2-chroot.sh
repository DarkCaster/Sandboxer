#!/bin/bash

# download and extract opensuse 42.2 root-fs image from docker repository

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

"$script_dir/download-image-from-docker-repo.sh" opensuse 42.2 openSUSE-42.2.tar.xz
check_errors "download-image-from-docker-repo.sh script failed!"

#remove machine-id, will be generated automatically
rm -f "$script_dir/debian_chroot/etc/machine-id"
check_errors
