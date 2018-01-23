#!/bin/bash

script_dir="$( cd "$( dirname "$0" )" && pwd )"

set -e

echo "creating new key and certificate used for signing"
openssl req -nodes -x509 -sha512 -newkey rsa:8192 -keyout "$script_dir/private.key" -out "$script_dir/public.crt" -days 36500 -subj "/CN=PUBLIC/"

echo "encrypting private key"
openssl aes-256-cbc -a -salt -in "$script_dir/private.key" -out "$script_dir/private.key.enc"

echo "removing unencrypted key"
rm private.key
