#!/bin/bash

# package binary components, build by build.sh script

set -e

build="$1"

[[ -z $build ]] && echo "usage: <build id>" && exit 1

srcdir="$(cd "$(dirname "$0")" && pwd)"
cd "$srcdir/../Build"

#get source-checksum
source_checksum=$("commander/commander" 2>/dev/null || true)
[[ -z $source_checksum ]] && echo "failed to read correct source_checksum from commander!" && exit 1

rm -rf "executor-$build-$source_checksum"
cp -r "executor" "executor-$build-$source_checksum"

rm -rf "x11util-$build"
cp -r "x11util" "x11util-$build"

[[ ! -d fixups/fakeroot-$build ]] && echo "fakeroot-$build not found. Run \"./build.sh\" script with \"$build\" parameter" && exit 1

rm -rf "fakeroot-$build"
cp -r "fixups/fakeroot-$build" "fakeroot-$build"

tar cf "executor-$build-$source_checksum.tar" "executor-$build-$source_checksum" --owner=0 --group=0
xz -9e "executor-$build-$source_checksum.tar"

tar cf "extra-binaries-$build.tar" "fakeroot-$build" "x11util-$build" --owner=0 --group=0
xz -9e "extra-binaries-$build.tar"
