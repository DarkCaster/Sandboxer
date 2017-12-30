#!/bin/bash

# download and extract opensuse 42.3 root-fs image from docker repository

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

"$script_dir/download-image-from-docker-repo.sh" opensuse 42.3 amd64 openSUSE-Leap-42.3.base.x86_64.tar.xz
check_errors "download-image-from-docker-repo.sh script failed!"

#remove "installrecommends = no" for zypper, that was defined on image builds
sed -i -e 's|^installRecommends.*$|# installRecommends = yes|g' "$script_dir/opensuse_chroot/etc/zypp/zypper.conf"

#remove machine-id, will be generated automatically
rm -f "$script_dir/opensuse_chroot/etc/machine-id"
check_errors

#create boot directory, if not exist
mkdir -p "$script_dir/opensuse_chroot/boot"

echo "#!/bin/sh" > "$script_dir/opensuse_chroot/root/bootstrap-minimal.sh"
echo "zypper ref --force; zypper up -l -y; zypper install -l -y dbus-1 aaa_base fipscheck glibc-locale ncurses-utils udev psmisc" >> "$script_dir/opensuse_chroot/root/bootstrap-minimal.sh"
chmod 755 "$script_dir/opensuse_chroot/root/bootstrap-minimal.sh"

echo "#!/bin/sh" > "$script_dir/opensuse_chroot/root/bootstrap-yast2.sh"
echo "zypper ref --force; zypper up -l -y; zypper install -l -y yast2-packager yast2-country yast2-fonts yast2-online-update-frontend yast2-online-update yast2-x11 yast2-qt yast2-qt-branding-openSUSE libyui-qt-pkg libyui-qt-graph xorg-x11-fonts gnu-free-fonts" >> "$script_dir/opensuse_chroot/root/bootstrap-yast2.sh"
chmod 755 "$script_dir/opensuse_chroot/root/bootstrap-yast2.sh"

#echo some notes
echo "***********************************************"
echo "opensuse_chroot directory preparation complete."
echo "it is recommended to install some packages that will make this stripped down docker-based chroot more suitable for regular usage"
echo "launch fakeroot_shell with this command \"sandboxer.sh opensuse-setup.cfg.lua fakeroot_shell\""
echo "then execute \"zypper ref --force; zypper install dbus-1 aaa_base fipscheck glibc-locale ncurses-utils udev psmisc\""
echo "if you want to use nice yast2 package manager with GUI, execute \"zypper install yast2-packager yast2-country yast2-fonts yast2-online-update-frontend yast2-online-update yast2-x11 yast2-qt yast2-qt-branding-openSUSE libyui-qt-pkg libyui-qt-graph xorg-x11-fonts gnu-free-fonts\""
echo "i have placed bootstrap-minimal.sh and bootstrap-yast2.sh scripts with this commands at chroot /root directory"
