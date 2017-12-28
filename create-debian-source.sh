#!/bin/bash
#

set -e

curdir="$( cd "$( dirname "$0" )" && pwd )"

target="$1"
key="$2"
version="$3"
distro="$4"

[[ -z $target ]] && echo "usage: create-debian-source.sh <target directory> [sign key id; \"none\" to skip] [version suffix (.ppa1~xenial for example); \"none\" to skip] [distroseries; \"none\" to use default \"unstable\"]" && exit 1
[[ $key = none ]] && key=""
[[ $version = none ]] && version=""
[[ $distro = none ]] && distro=""

mkdir -p "$target/sandboxer"

git archive --format tar HEAD | (cd "$target/sandboxer" && tar xf -)

[[ ! -f $curdir/BashLuaHelper/lua-helper.bash.in ]] && git submodule update --init
cd "$curdir/BashLuaHelper"
git archive --format tar HEAD | (cd "$target/sandboxer/BashLuaHelper" && tar xf -)
cd "$target/sandboxer"

[[ -z $distro ]] && sed -i "s|__DISTRO__|unstable|g" "$target/sandboxer/debian/changelog"
[[ ! -z $distro ]] && sed -i "s|__DISTRO__|""$distro""|g" "$target/sandboxer/debian/changelog"
sed -i "s|__VERSION__SUFFIX__|""$version""|g" "$target/sandboxer/debian/changelog"

if [[ -z $key ]]; then
  dpkg-buildpackage -d -S -us -uc
else
  dpkg-buildpackage -d -S -k$key
fi

cd "$target"
rm -rf "$target/sandboxer"
