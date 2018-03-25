#!/bin/bash

# download selected ubuntu distro from https://partner-images.canonical.com

script_dir="$( cd "$( dirname "$0" )" && pwd )"

show_usage() {
  echo "usage: download-ubuntu-chroot.sh <distro's major version number (16.04, for example)> [arch. only i386 and amd64 (default) supported now]"
  exit 1
}

set -e

prefix="$1"
[[ -z $prefix ]] && show_usage
prefix=`echo "$prefix" | tr '[:upper:]' '[:lower:]'`

case "$prefix" in
  "12.04")
    prefix="unsupported/precise"
    name="precise"
  ;;
  "14.04")
    prefix="trusty"
    name="trusty"
  ;;
  "16.04")
    prefix="xenial"
    name="xenial"
  ;;
  "18.04")
    prefix="bionic"
    name="bionic"
  ;;
  *)
    echo "selected ubuntu distro version is not supported. for now supported versions include 12.04;14.04;16.04;18.04"
    show_usage
  ;;
esac

arch="$2"
[[ -z $arch ]] && arch="amd64"
[[ $arch != amd64 && $arch != i386 ]] && \
  echo "selected arch $arch is not supported for now and may not work with sandboxer!" && \
  exit 1

# download and extract rootfs archive
wget -q --show-progress -O /tmp/ubuntu-root.tar.gz "https://partner-images.canonical.com/core/$prefix/current/ubuntu-$name-core-cloudimg-$arch-root.tar.gz"
mkdir "$script_dir/debian_chroot"
cd "$script_dir/debian_chroot"
gunzip -c /tmp/ubuntu-root.tar.gz | tar xf - --no-same-owner --preserve-permissions --exclude='dev'
rm /tmp/ubuntu-root.tar.gz

if [[ $name = xenial || $name = bionic ]]; then
  # deploy minimal setup script
  cp "$script_dir/debian-minimal-setup.sh" "$script_dir/debian_chroot/root/debian-minimal-setup.sh"
fi

cd "$script_dir/debian_chroot"

# make dpkg a lillte bit faster
echo "force-unsafe-io" > "etc/dpkg/dpkg.cfg.d/force-unsafe-io"

# create exclude rules for dpkg if missing
if [[ ! -f etc/dpkg/dpkg.cfg.d/excludes ]]; then
  echo "creating rule for dpkg to exclude manuals and docs when installing packages"
  echo "path-exclude=/usr/share/man/*" > "etc/dpkg/dpkg.cfg.d/excludes"
  echo "path-exclude=/usr/share/doc/*" >> "etc/dpkg/dpkg.cfg.d/excludes"
  echo "path-include=/usr/share/doc/*/copyright" >> "etc/dpkg/dpkg.cfg.d/excludes"
  echo "path-include=/usr/share/doc/*/changelog.Debian.*" >> "etc/dpkg/dpkg.cfg.d/excludes"
fi

if [[ $name = bionic ]]; then
  # modify config for apt, to make it work under fakeroot
  echo "modifying apt config options to make it work with sandboxer/fakeoot restrictions"
  echo "APT::Sandbox::Seccomp::Allow { \"socket\" };" > "etc/apt/apt.conf.d/99sandboxer"
  echo "APT::Sandbox::Seccomp::Allow { \"connect\" };" >> "etc/apt/apt.conf.d/99sandboxer"
fi

if [[ $name = trusty || $name = xenial || $name = bionic ]]; then
  echo "modifying apt config options to use gzipped indexes"
  echo "Acquire::GzipIndexes \"true\";" >> "etc/apt/apt.conf.d/99sandboxer"
fi

# write arch-label file
[[ ! -z $arch ]] && echo "$arch" > "arch-label"

# create boot directory if missing
mkdir -p ./boot

# remove machine-id, will be generated automatically
rm -f ./etc/machine-id

# check for merged root-fs layout, and mark it
# see https://wiki.debian.org/UsrMerge for more info
fs_layout="merged"
[[ -d ./bin && ! -L ./bin ]] && fs_layout="normal"
[[ -d ./sbin && ! -L ./sbin ]] && fs_layout="normal"
[[ -d ./lib && ! -L ./lib ]] && fs_layout="normal"
[[ -d ./lib32 && ! -L ./lib32 ]] && fs_layout="normal"
[[ -d ./lib64 && ! -L ./lib64 ]] && fs_layout="normal"
[[ -d ./libx32 && ! -L ./libx32 ]] && fs_layout="normal"
echo "$fs_layout" > "fs-layout"
