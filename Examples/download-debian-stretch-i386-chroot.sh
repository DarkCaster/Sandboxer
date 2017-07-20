#!/bin/bash

# download and extract debian stretch root-fs image from docker repository

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

"$script_dir/download-image-from-docker-repo.sh" debian stretch i386 rootfs.tar.xz
check_errors "download-image-from-docker-repo.sh script failed!"

#remove apt configs needed only for docker (see https://github.com/docker/docker/blob/master/contrib/mkimage/debootstrap)
rm "$script_dir/debian_chroot/etc/apt/apt.conf.d/docker-"*
check_errors

#remove machine-id, will be generated automatically
rm -f "$script_dir/debian_chroot/etc/machine-id"
check_errors

echo "i386" > "$script_dir/debian_chroot/arch-label"
check_errors

cp "$script_dir/debian-minimal-setup.sh" "$script_dir/debian_chroot/root/debian-minimal-setup.sh"
check_errors