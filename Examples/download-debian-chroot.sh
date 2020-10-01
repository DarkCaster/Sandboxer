#!/bin/bash

# download selected debian-choot from docker image repository
# may not work sometimes (after major changes in docker's debian repo structure)

# In order to setup debian chroot with sandboxer, you need to do the following:
# 0. make sure you are running this steps as regular unpriveleged user (thats the point of using sandboxer).
# 1. make sure that sandboxer-fakeroot package is installed, if building from source - it will be built and installed with sandboxer suite
# 2. you may want to deploy chroot and sandboxer config files in a separate directory, just make sure that following files (or symlinks to it) are there:
#  - download-debian-chroot.sh - this script, it will download and extract minimal debian distro image to "debian_sandbox" subdirectory
#  - download-image-from-docker-repo.sh - helper script, used to download minimal debian chroot image from docker repository
#  - debian-minimal-setup.sh - helper script, may be removed after chroot deploy
#  - debian-setup.cfg.lua - sandboxer config file that may be used to alter debian chroot: run apt-get, install new packages, update configuration, etc. NOT FOR REGULAR USE
#  - debian-version-probe.lua.in - helper script for debian\ubuntu-based setups, do not remove
#  - debian-sandbox.cfg.lua - sandboxer config file for running regular applications, chroot-subdirectories will be mounted read-only as if running regular linux session with unpriveleged user
# 3. run "download-debian-chroot.sh" in order to download supported debian image (run without args in order to see usage info).
# 4. run "sandboxer debian-setup.cfg.lua fakeroot_shell" to start sandboxer-session with fakeroot emulating running this sandbox as root.
# 5. configure your new debian sandbox - install new application with apt, modify config files, etc...
# 5.a as alternative you may run "/root/debian-minimal-setup.sh" while running sandboxer's fakeroot shell to perform automatic setup of minimal sandbox with X11 suitable for desktop use
# 6. when done - just type "exit", if there is no active sessions running this chroot for a while - sandboxer will automatically terminate it's session manager running for this chroot and perform some cleanup.
# 6.a you may force-terminate all processes and session manager for this sandbox by executing "sandboxer-term debian-setup.cfg.lua" (from host system)
# 7. run "sandboxer debian-sandbox.cfg.lua shell" to start sandbox in a unpriveleged-user mode, you may run your own stuff by using this config file, see examples for more info

# NOTE: you may need to run "sandboxer-download-extra" script in order to download prebuilt binary components for run with older debian chroots - this is optional, do not run this if all working well. Downloaded components will be placed at ~/.cache/sandboxer , you may remove it if not needed. Prebuilt binaries updated not very often and it's my be outdated and not work as intended, however it may help to run ancient debian chroot on a never host system.



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
  "11"|"bullseye")
    name="bullseye"
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
[[ $arch != amd64 && $arch != i386 ]] && \
  echo "selected arch $arch is not supported for now and may not work with sandboxer!" && \
  exit 1

echo "downloading debian $name with $arch arch from docker repository"
"$script_dir/download-image-from-docker-repo.sh" debian "$name" "$arch"

# remove apt configs needed only for docker (see https://github.com/docker/docker/blob/master/contrib/mkimage/debootstrap)
rm "$script_dir/debian_chroot/etc/apt/apt.conf.d/docker-"*

# deploy minimal setup script
cp "$script_dir/debian-minimal-setup.sh" "$script_dir/debian_chroot/root/debian-minimal-setup.sh"

# create exclude rules for dpkg if missing
if [[ ! -f etc/dpkg/dpkg.cfg.d/excludes ]]; then
  echo "creating rule for dpkg to exclude manuals and docs when installing packages"
  echo "path-exclude=/usr/share/man/*" > "etc/dpkg/dpkg.cfg.d/excludes"
  echo "path-exclude=/usr/share/doc/*" >> "etc/dpkg/dpkg.cfg.d/excludes"
  echo "path-include=/usr/share/doc/*/copyright" >> "etc/dpkg/dpkg.cfg.d/excludes"
  echo "path-include=/usr/share/doc/*/changelog.Debian.*" >> "etc/dpkg/dpkg.cfg.d/excludes"
fi

if [[ $name = sid || $name = buster || $name = bullseye ]]; then
  # modify config for apt, to make it work under fakeroot
  echo "modifying apt config options to make it work with sandboxer/fakeoot restrictions"
  echo "APT::Sandbox::Seccomp::Allow { \"socket\" };" > "$script_dir/debian_chroot/etc/apt/apt.conf.d/99-sandboxer"
  echo "APT::Sandbox::Seccomp::Allow { \"connect\" };" >> "$script_dir/debian_chroot/etc/apt/apt.conf.d/99-sandboxer"
fi
