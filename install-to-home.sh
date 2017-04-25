#!/bin/bash

# Install sandboxer suite to local user home directory
# You must build all required binaries before running this script: run build.sh and build-bwrap.sh (optionally).

target="$1"
[[ -z $target ]] && target="$HOME/sandboxer"
[[ $target = $HOME ]] && echo "will not proceed install to home directory directly, try $HOME/sandboxer sub-directory instead"

curdir="$( cd "$( dirname "$0" )" && pwd )"

check_error() {
 if [[ $? != 0 ]]; then
  echo "Install ended with error !!!"
  cd "$curdir"
  exit 1
 fi
}

echo "Installing sandboxer suite to $target directory"

mkdir -p "$target"
check_error

rm -rf "$target/bin"

mkdir -p "$target/examples"
check_error

mkdir -p "$target/bin"
check_error

# install main scripts
echo "Installing main scripts"

cp "$curdir/Sandboxer/sandboxer.sh" "$target/bin"
check_error

cp "$curdir/Sandboxer/sandboxer-desktop-file-creator.sh" "$target/bin"
check_error

cp "$curdir/Sandboxer/sandboxer.pre.lua" "$target/bin"
check_error

cp "$curdir/Sandboxer/sandboxer.post.lua" "$target/bin"
check_error

cp -r "$curdir/Sandboxer/fixups" "$target/bin"
check_error

cp -r "$curdir/Sandboxer/includes" "$target/bin"
check_error

cp -r "$curdir/Sandboxer/tools" "$target/bin"
check_error

echo "Installing service binaries"

cp -r "$curdir/Build/commander" "$target/bin"
check_error

cp -r "$curdir/Build/executor" "$target/bin"
check_error

cp -r "$curdir/Build/x11util" "$target/bin"
check_error

cp -r "$curdir/Build/fixups" "$target/bin"
check_error

"$curdir/BashLuaHelper/install.sh" "$target/bin/BashLuaHelper"
check_error

# copy examples

echo "Installing examples"

for example in "$target/examples"/*.cfg.lua "$target/examples"/*.sh
do
  [[ ! -f $example ]] && continue
  echo "Moving existing example $example to $example.bak"
  mv "$example" "$example.bak"
  check_error
done

for example in "$curdir/Examples"/*.cfg.lua "$curdir/Examples"/*.sh
do
  [[ ! -f $example ]] && continue
  cp "$example" "$target/examples"
  check_error
done

echo "Creating symlinks"

[[ ! -d $HOME/bin ]] && mkdir -p "$HOME/bin"

rm -f "$HOME/bin/sandboxer"
check_error

ln -s "$target/bin/sandboxer.sh" "$HOME/bin/sandboxer"
check_error

rm -f "$HOME/bin/sandboxer-desktop-file-creator.sh"
check_error

ln -s "$target/bin/sandboxer-desktop-file-creator.sh" "$HOME/bin/sandboxer-desktop-file-creator.sh"
check_error

find "$target" -type f -name "*.sh" -exec "$curdir/update_shebang.sh" {} \;
find "$target" -type f -name "*.sh.in" -exec "$curdir/update_shebang.sh" {} \;
