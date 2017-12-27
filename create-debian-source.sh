#!/bin/bash
#

set -e

target="$1"

curdir="$( cd "$( dirname "$0" )" && pwd )"

[[ -z $target ]] && echo "usage: create-debian-source.sh <target directory>" && exit 1

mkdir -p "$target/sandboxer"

[[ ! -f $curdir/BashLuaHelper/lua-helper.bash.in ]] && git submodule update --init

git archive --format tar HEAD | (cd "$target/sandboxer" && tar xf -)

cd "$curdir/BashLuaHelper"

git archive --format tar HEAD | (cd "$target/sandboxer/BashLuaHelper" && tar xf -)

cd "$target/sandboxer"

dpkg-buildpackage -d -S -us -uc

cd "$target"

rm -rf "$target/sandboxer"
