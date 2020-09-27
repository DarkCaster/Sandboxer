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

cur_date=`LANG=C date '+%a, %d %b %Y'`

mkdir -p "$target/sandboxer"
if [[ -d $curdir/.git ]]; then
  git archive --format tar HEAD | (cd "$target/sandboxer" && tar xf -)
  [[ ! -f $curdir/BashLuaHelper/lua-helper.bash.in ]] && git submodule update --init
  (cd "$curdir/BashLuaHelper" && git archive --format tar HEAD) | (cd "$target/sandboxer/BashLuaHelper" && tar xf -)
else
  cp -r "$curdir"/* "$target/sandboxer"
  [[ ! -f $target/sandboxer/BashLuaHelper/lua-helper.bash.in ]] && git clone "https://github.com/DarkCaster/Bash-Lua-Helper.git" "$target/sandboxer/BashLuaHelper"
  rm -rf "$target/sandboxer/BashLuaHelper"/{.git,.gitignore}
  rm -rf "$target/sandboxer"/{.git,.gitignore,.gitmodules}
fi

cd "$target/sandboxer"
[[ -z $distro ]] && sed -i "s|__DISTRO__|unstable|g" "debian/changelog"
[[ ! -z $distro ]] && sed -i "s|__DISTRO__|""$distro""|g" "debian/changelog"
sed -i "s|__VERSION__|""$version""|g" "debian/changelog"
sed -i "s|__DATE__|""$cur_date""|g" "debian/changelog"

if [[ -z $key ]]; then
  dpkg-buildpackage -d -S -us -uc
else
  dpkg-buildpackage -d -S -k$key
fi

cd ..
rm -rf "sandboxer"
