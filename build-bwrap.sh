#!/bin/bash

# Download, build bwrap utility and install it to /usr/local
# Require root priveleges, will ask for password (user or root), at install stage

curdir="$( cd "$( dirname "$0" )" && pwd )"

function check_error {
  if [[ $? != 0 ]]; then
    echo "Build ended with error !!!"
    cd "$curdir"
    exit 1
  fi
}

cd "$curdir"

if [[ ! -d $curdir/External/Bwrap ]]; then
  git clone https://github.com/projectatomic/bubblewrap.git "$curdir/External/Bwrap"
  check_error
fi

cd "$curdir/External/Bwrap"
check_error

&>/dev/null make distclean

NOCONFIGURE=YES ./autogen.sh
check_error

rm -rf "$curdir/Build/Bwrap-build"
mkdir -p "$curdir/Build/Bwrap-build" && cd "$curdir/Build/Bwrap-build"
check_error

"$curdir/External/Bwrap/configure" --prefix="/usr/local" --with-priv-mode=setuid --without-bash-completion-dir
check_error

make
check_error

sudo make install
check_error
