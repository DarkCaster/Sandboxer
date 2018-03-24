#!/bin/bash

# download selected debian-choot from docker image repository
# may not work sometimes (after major changes in docker's debian repo structure)

script_dir="$( cd "$( dirname "$0" )" && pwd )"

show_usage() {
  echo "usage: download-debian-chroot.sh <distro's major version number or codename> [arch. only i386 and amd64 (default) supported now]"
  exit 1
}

set -e

name="$1"
[[ -z $name ]] && show_usage
name=`echo "$name" | tr '[:upper:]' '[:lower:]'`

case "$name" in
  "8"|"jessie")
    name="jessie"
  ;;
  "9"|"stretch")
    name="stretch"
  ;;
  "10"|"buster")
    name="buster"
  ;;
  "sid")
    name="sid"
  ;;
  *)
    echo "selected debian distro name or version currently is not supported"
    show_usage
  ;;
esac

arch="$2"
[[ -z $arch ]] && arch="amd64"
[[ $arch != amd64 && $arch != i386 ]] && "selected arch $arch is not supported for now and may not work with sandboxer!"

echo "downloading debian $name with $arch arch from docker repository"
"$script_dir/download-image-from-docker-repo.sh" debian "$name" "$arch"

# remove apt configs needed only for docker (see https://github.com/docker/docker/blob/master/contrib/mkimage/debootstrap)
rm "$script_dir/debian_chroot/etc/apt/apt.conf.d/docker-"*

# deploy minimal setup script
cp "$script_dir/debian-minimal-setup.sh" "$script_dir/debian_chroot/root/debian-minimal-setup.sh"
