#!/bin/bash

set -e

curdir="$( cd "$( dirname "$0" )" && pwd )"
rootdir="$curdir/.."

suffix="$1"
dist="$2"

[[ -z $suffix || -z $dist ]] && echo "usage: deploy-to-launchpad.sh <package suffix> <dist>" && exit 1

base="dpkg_private"

#cleanup, extract archive with private signing info
rm -rf "/tmp/$base"
"$curdir/extract-archive.sh" "$curdir/$base.enc" /tmp

#launchpad gpg-key id
key_id=`LANG=C gpg --dry-run --keyid-format long --verbose --import "/tmp/$base/launchpad.gpg.key" 2>&1 | grep "^gpg: sec" | awk '{print $3}' | cut -d'/' -f2`
[[ -z $key_id ]] && echo "failed to detect launcpad gpg-key id" && exit 1
gpg --import "/tmp/$base/launchpad.gpg.key"

#create dpkg source files
"$curdir/create-debian-source.sh" /tmp/sandboxer-dpkgs "$key_id" "$suffix" "$dist"

#deploy it to launchpad
sed -i "s|__PRIVATE_SSH_KEY__|/tmp/$base/launchpad.ssh.key|g" "/tmp/$base/dput.config"
dput -c "/tmp/$base/dput.config" launchpad /tmp/sandboxer-dpkgs/sandboxer_*.changes
