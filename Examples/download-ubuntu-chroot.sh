#!/bin/bash

# download selected ubuntu distro from https://partner-images.canonical.com

# In order to setup ubuntu chroot with sandboxer, you need to do the following:
# 0. make sure you are running this steps as regular unpriveleged user (thats the point of using sandboxer).
# 1. make sure that sandboxer-fakeroot package is installed, if building from source - it will be built and installed with sandboxer suite
# 2. you may want to deploy chroot and sandboxer config files in a separate directory, just make sure that following files (or symlinks to it) are there:
#  - download-ubuntu-chroot.sh - this script, it will download and extract minimal ubuntu-core distro image to "debian_sandbox" subdirectory
#  - debian-minimal-setup.sh - helper script, may be removed after chroot deploy
#  - debian-setup.cfg.lua - sandboxer config file that may be used to alter ubuntu chroot: run apt-get, install new packages, update configuration, etc. NOT FOR REGULAR USE
#  - debian-version-probe.lua.in - helper script for debian\ubuntu-based setups, do not remove
#  - debian-sandbox.cfg.lua - sandboxer config file for running regular applications, chroot-subdirectories will be mounted read-only as if running regular linux session with unpriveleged user
# 3. run "download-ubuntu-chroot.sh" in order to download supported ubuntu image (run without args in order to see usage info).
# 4. run "sandboxer debian-setup.cfg.lua fakeroot_shell" to start sandboxer-session with fakeroot emulating running this sandbox as root.
# 5. configure your new ubuntu sandbox - install new application with apt, modify config files, etc...
# 5.a as alternative you may run "/root/debian-minimal-setup.sh" while running sandboxer's fakeroot shell to perform automatic setup of minimal sandbox with X11 suitable for desktop use
# 6. when done - just type "exit", if there is no active sessions running this chroot for a while - sandboxer will automatically terminate it's session manager running for this chroot and perform some cleanup.
# 6.a you may force-terminate all processes and session manager for this sandbox by executing "sandboxer-term debian-setup.cfg.lua" (from host system)
# 7. run "sandboxer debian-sandbox.cfg.lua shell" to start sandbox in a unpriveleged-user mode, you may run your own stuff by using this config file, see examples for more info

# NOTE: you may need to run "sandboxer-download-extra" script in order to download prebuilt binary components for run with older ubuntu\debian chroots - this is optional, do not run this if all working well. Downloaded components will be placed at ~/.cache/sandboxer , you may remove it if not needed. Prebuilt binaries updated not very often and it's my be outdated and not work as intended, however it may help to run ancient ubuntu chroot on a never host system.

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
  "20.04")
    prefix="focal"
    name="focal"
  ;;
  "22.04")
    prefix="jammy"
    name="jammy"
  ;;
  "24.04")
    prefix="noble"
    name="noble"
  ;;
  *)
    echo "selected ubuntu distro version is not supported. for now supported versions include 12.04;14.04;16.04;18.04;20.04;22.04;24.04"
    show_usage
  ;;
esac

arch="$2"
[[ -z $arch ]] && arch="amd64"
[[ $arch != amd64 && $arch != i386 ]] && \
  echo "selected arch $arch is not supported for now and may not work with sandboxer!" && \
  exit 1

# try to download from docker repo
if [[ $name = noble ]]; then
  [[ $arch = i386 ]] && echo "selected arch $arch is not supported for this ubuntu release!" && exit 1
  echo "downloading ubuntu $name with $arch arch from dayly-builds cloud-img repository"
  # download and extract rootfs archive
  wget --help | grep -q '\--show-progress' && wget_opts="-q --show-progress" || wget_opts=""
  wget $wget_opts -O /tmp/ubuntu-root.tar.xz "https://cloud-images.ubuntu.com/minimal/daily/$name/current/$name-minimal-cloudimg-amd64-root.tar.xz"
  mkdir "$script_dir/debian_chroot"
  cd "$script_dir/debian_chroot"
  tar xJf /tmp/ubuntu-root.tar.xz --no-same-owner --preserve-permissions --exclude='dev'
  rm /tmp/ubuntu-root.tar.xz
else
  # download and extract rootfs archive
  wget --help | grep -q '\--show-progress' && wget_opts="-q --show-progress" || wget_opts=""
  wget $wget_opts -O /tmp/ubuntu-root.tar.gz "https://partner-images.canonical.com/core/$prefix/current/ubuntu-$name-core-cloudimg-$arch-root.tar.gz"
  mkdir "$script_dir/debian_chroot"
  cd "$script_dir/debian_chroot"
  gunzip -c /tmp/ubuntu-root.tar.gz | tar xf - --no-same-owner --preserve-permissions --exclude='dev'
  rm /tmp/ubuntu-root.tar.gz
fi

if [[ $name = xenial || $name = bionic || $name = focal || $name = jammy || $name = noble ]]; then
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

if [[ $name = bionic || $name = focal || $name = jammy ]]; then
  # modify config for apt, to make it work under fakeroot
  echo "modifying apt config options to make it work with sandboxer/fakeoot restrictions"
  echo "APT::Sandbox::Seccomp::Allow { \"socket\" };" > "etc/apt/apt.conf.d/99sandboxer"
  echo "APT::Sandbox::Seccomp::Allow { \"connect\" };" >> "etc/apt/apt.conf.d/99sandboxer"
fi

# cause huge slowdown for synaptic search
# if [[ $name = trusty || $name = xenial || $name = bionic ]]; then
#   echo "modifying apt config options to use gzipped indexes"
#   echo "Acquire::GzipIndexes \"true\";" >> "etc/apt/apt.conf.d/99sandboxer"
# fi

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

echo "download complete"
echo ""
echo "to finish setup or install packages inside ubuntu chroot, run:"
echo "sandboxer debian-setup.cfg.lua fakeroot_shell"
echo ""
echo "to run regular sandbox inside ubuntu chroot, run:"
echo "sandboxer debian-sandbox.cfg.lua shell"
