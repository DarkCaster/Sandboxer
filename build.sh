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
rm -rf "$curdir/Build"

mkdir -p "$curdir/Build/Executor"
check_error

cd "$curdir/Build/Executor"
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

make distclean

./bootstrap
check_error

mkdir -p "$curdir/Build/Fakeroot-UserNS"
check_error

cd "$curdir/Build/Fakeroot-UserNS"
check_error

"$curdir/External/Fakeroot-UserNS/configure" --prefix=/fixups/fakeroot
check_error

make all
check_error

make doc
check_error

make install DESTDIR="$curdir/Build"
check_error
