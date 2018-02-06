#!/bin/bash

set -e

script_dir="$( cd "$( dirname "$0" )" && pwd )"
if [[ -d $script_dir/debian_chroot ]]; then
  echo "directory $script_dir/debian_chroot already exist!"
  exit 1
fi
wget -O /tmp/ubuntu-root.tar.gz https://partner-images.canonical.com/core/bionic/current/ubuntu-bionic-core-cloudimg-amd64-root.tar.gz
mkdir -p "$script_dir/debian_chroot"
cd "$script_dir/debian_chroot"
gunzip -c /tmp/ubuntu-root.tar.gz | tar xf - --no-same-owner --preserve-permissions --exclude='dev'
#remove machine-id, will be generated automatically
rm -f "$script_dir/debian_chroot/etc/machine-id"
rm /tmp/ubuntu-root.tar.gz
#copy setup script
cp "$script_dir/debian-minimal-setup.sh" "$script_dir/debian_chroot/root/debian-minimal-setup.sh"
