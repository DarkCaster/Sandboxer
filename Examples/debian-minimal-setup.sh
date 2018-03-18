#!/bin/sh

# perform some basic setup for fresh debian_chroot
# intended for run with debian-setup profile

set -e

# minimal setup
apt-get update
apt-get install dialog -y
apt-get install locales -y
dpkg-reconfigure locales
apt-get install apt-utils -y
dpkg-reconfigure dialog
dpkg-reconfigure apt-utils
apt-get install tzdata -y
dpkg-reconfigure tzdata
apt-get dist-upgrade -y

# additional packages for dbus, x11, mesa, pulse integration and package management gui (synaptic) with minimal x11 stack
apt-get install -y net-tools mc libpulse0 mesa-utils lsb-release wget adwaita-icon-theme synaptic xauth gnupg2 apt-transport-https
apt-get install -y adwaita-icon-theme-full || true
