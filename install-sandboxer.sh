#!/bin/bash

set -e

curdir="$( cd "$( dirname "$0" )" && pwd )"

target="$1"
bin_dir="$2"

[[ -z $bin_dir || -z $target ]] && echo "usage: install.sh <target dir> <bin dir>" && exit 1

echo "Installing sandboxer suite to $target directory"

mkdir -p "$target"
[[ -d $target/bin ]] && rm -rf "$target/bin"
mkdir -p "$target/bin"
mkdir -p "$target/examples"

# install main scripts
echo "Installing main scripts"
cp "$curdir/Sandboxer/sandboxer.sh" "$target/bin"
cp "$curdir/Sandboxer/sandboxer-desktop-file-creator.sh" "$target/bin"
cp "$curdir/Sandboxer/sandboxer-kill.sh" "$target/bin"
cp "$curdir/Sandboxer/sandboxer-term.sh" "$target/bin"
cp "$curdir/Sandboxer/sandboxer-stop-all.sh" "$target/bin"
cp "$curdir/Sandboxer/sandboxer-setup-phase-1.sh.in" "$target/bin"
cp "$curdir/Sandboxer/sandboxer-setup-phase-2.sh.in" "$target/bin"
cp "$curdir/Sandboxer/sandboxer.pre.lua" "$target/bin"
cp "$curdir/Sandboxer/sandboxer.post.lua" "$target/bin"
cp -r "$curdir/Sandboxer/fixups" "$target/bin"
cp -r "$curdir/Sandboxer/includes" "$target/bin"
cp -r "$curdir/Sandboxer/tools" "$target/bin"

echo "Installing service binaries"
[[ -d $curdir/Build/commander ]] && cp -r "$curdir/Build/commander" "$target/bin"
[[ -d $curdir/Build/executor ]] && cp -r "$curdir/Build/executor" "$target/bin"
[[ -d $curdir/Build/x11util ]] && cp -r "$curdir/Build/x11util" "$target/bin"
[[ -d $curdir/Build/fixups ]] && cp -r "$curdir/Build/fixups" "$target/bin"
"$curdir/BashLuaHelper/install.sh" "$target/bin/BashLuaHelper"

# copy examples
echo "Installing examples"

for example in "$target/examples"/*.cfg.lua "$target/examples"/*.sh "$target/examples"/*.txt "$target/examples"/*.lua.in
do
  [[ ! -f $example ]] && continue
  echo "Moving existing example $example to $example.bak"
  mv "$example" "$example.bak"
done

for example in "$curdir/Examples"/*.cfg.lua "$curdir/Examples"/*.sh "$curdir/Examples"/*.txt "$curdir/Examples"/*.lua.in
do
  [[ ! -f $example ]] && continue
  cp "$example" "$target/examples"
done

echo "Creating symlinks"

[[ ! -d $bin_dir ]] && mkdir -p "$bin_dir"

rm -f "$bin_dir/sandboxer"
ln -s "$target/bin/sandboxer.sh" "$bin_dir/sandboxer"
rm -f "$bin_dir/sandboxer-kill"
ln -s "$target/bin/sandboxer-kill.sh" "$bin_dir/sandboxer-kill"
rm -f "$bin_dir/sandboxer-term"
ln -s "$target/bin/sandboxer-term.sh" "$bin_dir/sandboxer-term"
rm -f "$bin_dir/sandboxer-stop-all"
ln -s "$target/bin/sandboxer-stop-all.sh" "$bin_dir/sandboxer-stop-all"
rm -f "$bin_dir/sandboxer-desktop-file-creator.sh"
ln -s "$target/bin/sandboxer-desktop-file-creator.sh" "$bin_dir/sandboxer-desktop-file-creator.sh"
find "$target" -type f -name "*.sh" -exec "$curdir/update_shebang.sh" {} \;
find "$target" -type f -name "*.sh.in" -exec "$curdir/update_shebang.sh" {} \;
