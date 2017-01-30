#!/bin/bash

#build executor\commander binaries for local-user installation

curdir="$( cd "$( dirname "$0" )" && pwd )"

function check_error {
 if [ "$?" != "0" ]; then
  echo "Build ended with error !!!"
  cd "$curdir"
  exit 1
 fi
}

cd "$curdir"
rm -rf "$curdir/Build/Executor"

mkdir -p "$curdir/Build/Executor"
check_error

cd "$curdir/Build/Executor"
check_error

cmake -DCMAKE_BUILD_TYPE=Release ../../Executor
check_error

make
check_error

