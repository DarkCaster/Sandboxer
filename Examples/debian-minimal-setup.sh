#!/bin/sh

# perform some basic setup for fresh debian_chroot
# intended for run with debian-setup profile

check_errors () {
  local status="$?"
  local msg="$@"
  if [ "$status" != "0" ]; then
    echo "ERROR: operation finished with error code $status"
    [ ! -z "$msg" ] && echo "$msg"
    exit "$status"
  fi
}

apt-get update
check_errors

apt-get install dialog -y
check_errors

apt-get install locales -y
check_errors

dpkg-reconfigure locales
check_errors

apt-get install apt-utils -y
check_errors

dpkg-reconfigure dialog
check_errors

dpkg-reconfigure apt-utils
check_errors

apt-get install tzdata -y
check_errors

dpkg-reconfigure tzdata
check_errors

# additional packages for dbus, x11, mesa, pulse integration and package management gui (synaptic) with minimal x11 stack
apt-get install -y net-tools mc libpulse0 mesa-utils lsb-release wget synaptic xauth gnupg2
check_errors

apt-get dist-upgrade -y
check_errors
