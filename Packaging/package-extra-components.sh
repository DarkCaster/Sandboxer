#!/bin/bash

# package binary components, build by build.sh script

#TODO
echo "TODO: update this script to use with travis-ci"
exit 1

build="$1"

[[ -z $build ]] && echo "usage: <build id>" && exit 1

curdir="$( cd "$( dirname "$0" )" && pwd )"

function check_error {
 if [[ $? != 0 ]]; then
  echo "Build ended with error !!!"
  cd "$curdir"
  exit 1
 fi
}

cd "$curdir/Build"
check_error

#get source-checksum
source_checksum=`2>/dev/null "commander/commander"`
[[ -z $source_checksum ]] && echo "failed to read correct source_checksum from commander!" && exit 1

rm -rf "executor-$build-$source_checksum"
check_error

cp -r "executor" "executor-$build-$source_checksum"
check_error

rm -rf "x11util-$build"
check_error

cp -r "x11util" "x11util-$build"
check_error

[[ ! -d fixups/fakeroot-$build ]] && echo "fakeroot-$build not found. Run \"./build.sh\" script with \"$build\" parameter" && exit 1

rm -rf "fakeroot-$build"
check_error

cp -r "fixups/fakeroot-$build" "fakeroot-$build"
check_error

# TODO: sign archives

tar cf "executor-$build-$source_checksum.tar" "executor-$build-$source_checksum" --owner=0 --group=0
xz -9e "executor-$build-$source_checksum.tar"

tar cf "extra-binaries-$build.tar" "fakeroot-$build" "x11util-$build" --owner=0 --group=0
xz -9e "extra-binaries-$build.tar"
