#!/bin/bash

#build executor\commander binaries for local-user installation

curdir="$( cd "$( dirname "$0" )" && pwd )"

function check_error {
 if [ "$?" != "0" ]; then
  echo "Build ended with error !!!"
  cd "$curdir"
  exit 1
 fi
}

# Executor and Commander utils

cd "$curdir"
rm -rf "$curdir/Build/Executor-build"

mkdir -p "$curdir/Build/Executor-build" && cd "$curdir/Build/Executor-build"
check_error

cmake -DCMAKE_INSTALL_PREFIX="$curdir/Build" -DCMAKE_BUILD_TYPE=Release ../../Executor
check_error

make
check_error

make install
check_error

# X11Util

cd "$curdir"
rm -rf "$curdir/Build/X11Util-build"

mkdir -p "$curdir/Build/X11Util-build" && cd "$curdir/Build/X11Util-build"
check_error

cmake -DCMAKE_INSTALL_PREFIX="$curdir/Build" -DCMAKE_BUILD_TYPE=Release ../../X11Util
check_error

make
check_error

make install
check_error

# Fakeroot-UserNS

mkdir -p "$curdir/External"
check_error

if [ ! -d "$curdir/External/Fakeroot-UserNS" ]; then
 git clone https://github.com/DarkCaster/Fakeroot-UserNS.git "$curdir/External/Fakeroot-UserNS"
 check_error
fi

cd "$curdir/External/Fakeroot-UserNS"
check_error

&>/dev/null make distclean

./preroll
check_error

rm -rf "$curdir/Build/Fakeroot-UserNS-build"
rm -rf "$curdir/Build/fixups/fakeroot"/*

mkdir -p "$curdir/Build/Fakeroot-UserNS-build" && cd "$curdir/Build/Fakeroot-UserNS-build"
check_error

"$curdir/External/Fakeroot-UserNS/configure" --prefix=/fixups/fakeroot-host --bindir=/fixups/fakeroot-host --libdir=/fixups/fakeroot-host --mandir=/fixups/fakeroot-host/man --with-ipc=tcp
check_error

make
check_error

make install DESTDIR="$curdir/Build"
check_error
