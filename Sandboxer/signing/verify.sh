#!/bin/bash

script_dir="$( cd "$( dirname "$0" )" && pwd )"

set -e

target="$1"
[[ -z $target ]] && echo "usage: verify.sh <target file>" && exit 1
[[ ! -f $target ]] && echo "target file $target not found!" && exit 1
[[ ! -f $target.sign ]] && echo "signature for target file $target not found!" && exit 1

openssl dgst -sha512 -verify <(openssl x509 -in "$script_dir/public.crt" -pubkey -noout) -signature "$target.sign" "$target"
