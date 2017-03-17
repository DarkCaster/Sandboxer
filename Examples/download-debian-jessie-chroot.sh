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

"$script_dir/download-debian-from-docker-repo.sh" jessie
check_errors

#remove apt configs needed only for docker (see https://github.com/docker/docker/blob/master/contrib/mkimage/debootstrap)
rm "$script_dir/debian_chroot/etc/apt/apt.conf.d/docker-"*
check_errors

#remove machine-id, will be generated automatically
rm -f "$script_dir/debian_chroot/etc/machine-id"
check_errors
