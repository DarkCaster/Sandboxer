#!/bin/bash

# Install sandboxer suite to local user home directory
# You must build all required binaries before running this script: run build.sh and build-bwrap.sh (optionally).

target="$1"
[[ -z $target ]] && target="$HOME/sandboxer"
[[ $target = $HOME ]] && echo "will not proceed install to home directory directly, try $HOME/sandboxer sub-directory instead" && exit 1

curdir="$( cd "$( dirname "$0" )" && pwd )"

"$curdir/install-sandboxer.sh" "$target" "$HOME/bin"
