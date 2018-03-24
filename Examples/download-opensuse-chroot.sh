#!/bin/bash

# download and extract supported opensuse root-fs image from docker repository
# may not work sometimes (after major changes in docker's debian repo structure)

script_dir="$( cd "$( dirname "$0" )" && pwd )"

show_usage() {
  echo "usage: download-debian-chroot.sh <distro's major version number or codename> [arch. only i386 and amd64 (default) supported now]"
  exit 1
}

set -e

arch="$2"
[[ -z $arch ]] && arch="amd64"
[[ $arch != amd64 && $arch != i386 ]] && \
  echo "selected arch $arch is not supported for now and may not work with sandboxer!" && \
  exit 1

name="$1"
[[ -z $name ]] && show_usage
name=`echo "$name" | tr '[:upper:]' '[:lower:]'`

case "$name" in
  "42.2")
    name="42.2"
    arch="amd64"
  ;;
  "42.3"|"stretch")
    name="42.3"
    arch="amd64"
  ;;
  "tumbleweed")
    name="tumbleweed"
  ;;
  *)
    echo "selected opensuse distro name or version is not supported. supported versions include: 42.2, 42.3, tumbleweed"
    show_usage
  ;;
esac

"$script_dir/download-image-from-docker-repo.sh" opensuse "$name" "$arch"

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
