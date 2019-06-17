#!/bin/bash

# download and extract supported opensuse root-fs image from docker repository
# may not work sometimes (after major changes in docker's debian repo structure)

script_dir="$( cd "$( dirname "$0" )" && pwd )"

show_usage() {
  echo "usage: download-debian-chroot.sh <distro's major version number or codename> [arch. only i686 and amd64 (default) supported now. i686 may be selected only for tumbleweed (experimental)]"
  exit 1
}

set -e

arch="$2"
[[ -z $arch ]] && arch="amd64"
[[ $arch != amd64 && $arch != i686 ]] && \
  echo "selected arch $arch is not supported for now and may not work with sandboxer!" && \
  exit 1

name="$1"
[[ -z $name ]] && show_usage
name=`echo "$name" | tr '[:upper:]' '[:lower:]'`

case "$name" in
  "42.3")
    name="42.3"
    arch="amd64"
    url="https://download.opensuse.org/repositories/Virtualization:/containers:/images:/openSUSE-Leap-42.3/containers/opensuse-leap-image.x86_64-lxc.tar.xz"
  ;;
  "15.0")
    name="15.0"
    arch="amd64"
    url="https://download.opensuse.org/repositories/Virtualization:/containers:/images:/openSUSE-Leap-15.0/containers/opensuse-leap-image.x86_64-lxc.tar.xz"
  ;;
  "15.1")
    name="15.1"
    arch="amd64"
    url="https://download.opensuse.org/repositories/Virtualization:/containers:/images:/openSUSE-Leap-15.1/containers/opensuse-leap-image.x86_64-lxc.tar.xz"
  ;;
  "tumbleweed")
    name="tumbleweed"
    url=""
    if [[ $arch = amd64 ]]; then
      url="https://download.opensuse.org/repositories/Virtualization:/containers:/images:/openSUSE-Tumbleweed/container/opensuse-tumbleweed-image.x86_64-lxc.tar.xz"
    elif [[ $arch = i686 ]]; then
      url="https://download.opensuse.org/repositories/Virtualization:/containers:/images:/openSUSE-Tumbleweed/container/opensuse-tumbleweed-image.i686-lxc.tar.xz"
    fi
  ;;
  *)
    echo "selected opensuse distro name or version is not supported. supported versions include: 42.3, tumbleweed"
    show_usage
  ;;
esac

[[ -d "$script_dir/opensuse_chroot" ]] && echo "opensuse_chroot dir already exist in script dir, please remove it before running this script"

tmp_dir=`mktemp -d -t suse-XXXXXXXXX`
wget -O "$tmp_dir/rootfs.tar.xz" "$url"

mkdir -p "$script_dir/opensuse_chroot"
pushd "$script_dir/opensuse_chroot"

xz -d -c "$tmp_dir/rootfs.tar.xz" | tar xf - --no-same-owner --preserve-permissions --exclude='dev'

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

popd

#remove "installrecommends = no" for zypper, that was defined on image builds
sed -i -e 's|^installRecommends.*$|# installRecommends = yes|g' "$script_dir/opensuse_chroot/etc/zypp/zypper.conf"

echo "#!/bin/sh" > "$script_dir/opensuse_chroot/root/bootstrap-minimal.sh"
echo "zypper ref --force; zypper dup -l -y; zypper install -l -y dbus-1 aaa_base fipscheck glibc-locale ncurses-utils udev psmisc" >> "$script_dir/opensuse_chroot/root/bootstrap-minimal.sh"
chmod 755 "$script_dir/opensuse_chroot/root/bootstrap-minimal.sh"

echo "#!/bin/sh" > "$script_dir/opensuse_chroot/root/bootstrap-yast2.sh"
echo "zypper ref --force; zypper dup -l -y; zypper install -l -y yast2-packager yast2-country yast2-fonts yast2-online-update-frontend yast2-online-update yast2-x11 yast2-qt yast2-qt-branding-openSUSE libyui-qt-pkg libyui-qt-graph xorg-x11-fonts gnu-free-fonts" >> "$script_dir/opensuse_chroot/root/bootstrap-yast2.sh"
chmod 755 "$script_dir/opensuse_chroot/root/bootstrap-yast2.sh"

#echo some notes
echo "***********************************************"
echo "opensuse_chroot directory preparation complete."
echo "it is recommended to install some packages that will make this stripped down docker-based chroot more suitable for regular usage"
echo "launch fakeroot_shell with this command \"sandboxer opensuse-setup.cfg.lua fakeroot_shell\""
echo "and execute \"/root/bootstrap-minimal.sh\""
echo "if you also want to use nice yast2 package manager with GUI, execute \"/root/bootstrap-yast2.sh\" after previous line"
