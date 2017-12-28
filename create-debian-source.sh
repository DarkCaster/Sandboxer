#!/bin/bash
#

set -e

curdir="$( cd "$( dirname "$0" )" && pwd )"

target="$1"
distro="$2"
key="$3"

[[ -z $target ]] && echo "usage: create-debian-source.sh <target directory> [distroseries] [sign key id]" && exit 1

mkdir -p "$target/sandboxer"

git archive --format tar HEAD | (cd "$target/sandboxer" && tar xf -)

[[ ! -f $curdir/BashLuaHelper/lua-helper.bash.in ]] && git submodule update --init
cd "$curdir/BashLuaHelper"
git archive --format tar HEAD | (cd "$target/sandboxer/BashLuaHelper" && tar xf -)
cd "$target/sandboxer"

[[ -z $distro ]] && sed -i "s|__DISTRO__|unstable|g" "$target/sandboxer/debian/changelog"
[[ ! -z $distro ]] && sed -i "s|__DISTRO__|""$distro""|g" "$target/sandboxer/debian/changelog"

if [[ -z $key ]]; then
  dpkg-buildpackage -d -S -us -uc
else
  dpkg-buildpackage -d -S -k$key
fi

cd "$target"
rm -rf "$target/sandboxer"
