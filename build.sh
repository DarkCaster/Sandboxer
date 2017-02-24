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

cd "$curdir"
rm -rf "$curdir/Build/Executor"

mkdir -p "$curdir/Build/Executor" && cd "$curdir/Build/Executor"
check_error

cmake -DCMAKE_BUILD_TYPE=Release ../../Executor
check_error

make
check_error

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

rm -rf "$curdir/Build/Fakeroot-UserNS"
rm -rf "$curdir/Build/Fakeroot"

mkdir -p "$curdir/Build/Fakeroot-UserNS" && cd "$curdir/Build/Fakeroot-UserNS"
check_error

"$curdir/External/Fakeroot-UserNS/configure" --prefix=/fixups/fakeroot-host --bindir=/fixups/fakeroot-host --libdir=/fixups/fakeroot-host --mandir=/fixups/fakeroot-host/man --with-ipc=tcp
check_error

make
check_error

make install DESTDIR="$curdir/Build/Fakeroot"
check_error
