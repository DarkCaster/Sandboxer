#!/bin/bash

# Build all needed binaries for local-user homedir installation, or for direct execution from source directory (for debug and develop purposes)
# Build includes: executor, commander and x11util binaries, also download and build fakeroot-userns binaries from external repo.
# Root priveleges is not required for this script.
# Bwrap utility must be installed separately. It can be compiled and installed with build-bwrap.sh script, or may be installed from your distro's package management service.

# This script can also used to create downloadable binary packages of selected utilities for use with sandboxer-download-extra.sh script
# Pass (optional) parameter with build name, it will be used when compiling fakeroot
build="$1"

curdir="$( cd "$( dirname "$0" )" && pwd )"

set -eE
function process_error() {
  >&2 echo "command at line $1 has failed"
}
trap 'process_error $LINENO' ERR

# Executor and Commander utils
cd "$curdir"
rm -rf "$curdir/Build/Executor-build"
mkdir -p "$curdir/Build/Executor-build"
cd "$curdir/Build/Executor-build"
cmake -DCMAKE_INSTALL_PREFIX="$curdir/Build" -DCMAKE_BUILD_TYPE=Release ../../Executor
make
make install

# X11Util
cd "$curdir"
rm -rf "$curdir/Build/X11Util-build"
mkdir -p "$curdir/Build/X11Util-build"
cd "$curdir/Build/X11Util-build"
cmake -DCMAKE_INSTALL_PREFIX="$curdir/Build" -DCMAKE_BUILD_TYPE=Release ../../X11Util
make
make install

# Fakeroot-UserNS
mkdir -p "$curdir/External"
if [[ ! -d $curdir/External/Fakeroot-UserNS ]]; then
  function process_error() {
    echo "Fakeroot-UserNS configuration failed !!!"
    cd "$curdir"
    rm -rf "$curdir/External/Fakeroot-UserNS"
  }
  rm -rf "$curdir/External/Fakeroot-UserNS"
  cd "$curdir/External"
  git clone https://github.com/DarkCaster/Fakeroot-UserNS.git
  cd "$curdir/External/Fakeroot-UserNS"
  patch -p1 -i ./debian/patches/eglibc-fts-without-LFS
  patch -p1 -i ./debian/patches/glibc-xattr-types
  patch -p1 -i ./debian/patches/fix-shell-in-fakeroot
  patch -p1 -i ./debian/patches/hide-dlsym-error.patch
  # disable docs from building
  sed -i '/doc\//d' ./configure.ac
  sed -i '/po4a/d' ./preroll
  sed -i 's|doc||g' ./Makefile.am
  rm -rf ./doc
  # autoreconf
  ./preroll
  function process_error() {
    >&2 echo "command at line $1 has failed"
  }
fi

rm -rf "$curdir/Build/Fakeroot-UserNS-build"
rm -rf "$curdir/Build/fixups/fakeroot"/*
mkdir -p "$curdir/Build/Fakeroot-UserNS-build"
cd "$curdir/Build/Fakeroot-UserNS-build"

if [[ -z $build ]]; then
  "$curdir/External/Fakeroot-UserNS/configure" --prefix="/fixups/fakeroot-host" --bindir="/fixups/fakeroot-host" --libdir="/fixups/fakeroot-host" --mandir="/fixups/fakeroot-host/man" --with-ipc=sysv --with-pic --with-dbformat=path
else
  "$curdir/External/Fakeroot-UserNS/configure" --prefix="/fixups/fakeroot-$build" --bindir="/fixups/fakeroot-$build" --libdir="/fixups/fakeroot-$build" --mandir="/fixups/fakeroot-$build/man" --with-ipc=sysv --with-pic --with-dbformat=path
fi

make
make install DESTDIR="$curdir/Build"

cd "$curdir"

#remove all surplus stuff
find "$curdir/Build/fixups" -type f -name "*.a" -print -delete
find "$curdir/Build/fixups" -type f -name "*.la" -print -delete
find "$curdir/Build/fixups" -type f -name "faked" -print -exec strip --strip-unneeded {} \;
find "$curdir/Build/fixups" -type f -name "*.so" -print -exec strip --strip-unneeded {} \;
find "$curdir/Build/commander" -type f -print -exec strip --strip-unneeded {} \;
find "$curdir/Build/executor" -type f -print -exec strip --strip-unneeded {} \;
find "$curdir/Build/x11util" -type f -print -exec strip --strip-unneeded {} \;

[[ ! -f $curdir/BashLuaHelper/lua-helper.bash.in && -d $curdir/.git ]] && git submodule update --init
[[ ! -f $curdir/BashLuaHelper/lua-helper.bash.in && ! -d $curdir/.git ]] && git clone "https://github.com/DarkCaster/Bash-Lua-Helper.git" "$curdir/BashLuaHelper"
