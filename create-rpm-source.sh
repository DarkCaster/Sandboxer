#!/bin/bash
#

set -e

curdir="$( cd "$( dirname "$0" )" && pwd )"

target="$1"
version="$2"

[[ -z $target ]] && echo "usage: create-debian-source.sh <target directory> [version suffix, \"none\" to skip]" && exit 1
[[ $version = none ]] && version=""

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

cp "$curdir/sandboxer.spec.template" "$target/sandboxer.spec"
rm -rf "$target/sandboxer/debian"
rm -f "$target/sandboxer/create-rpm-source.sh"
rm -f "$target/sandboxer/create-debian-source.sh"
rm -f "$target/sandboxer/sandboxer.spec.template"
sed -i "s|__VERSION__SUFFIX__|""$version""|g" "$target/sandboxer.spec"

# todo: read full version
full_ver=""
mv "$target/sandboxer" "$target/sandboxer-$full_ver"
( cd "$target" && tar cf "sandboxer-$full_ver.tar" "sandboxer-$full_ver" --owner=0 --group=0 && xz -9e "sandboxer-$full_ver.tar" )
rm -rf "$target/sandboxer-$full_ver"
