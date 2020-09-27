#!/bin/bash

set -e

curdir="$( cd "$( dirname "$0" )" && pwd )"
rootdir="$curdir/.."

suffix="$1"
dist="$2"

[[ -z $suffix || -z $dist ]] && echo "usage: deploy-to-launchpad.sh <package suffix> <dist>" && exit 1

$base="dpkg_private"

#cleanup, extract archive with private signing info
rm -rf "/tmp/$base"
"$curdir/extract-archive.sh" "$curdir/$base.enc" /tmp

#launchpad gpg-key id
key_id=`LANG=C gpg --keyid-format long --import-options show-only --import "/tmp/$base/launchpad.gpg.key" | grep "^sec" | awk '{print $2}' | cut -d'/' -f2`
[[ -z $key_id ]] && echo "failed to detect launcpad gpg-key id" && exit 1
gpg --import "/tmp/$base/launchpad.gpg.key"
 
#create dpkg source files
"$curdir/create-debian-source.sh" /tmp/sandboxer-dpkgs "$key_id" "$suffix" "$dist"

#deploy it to launchpad
# sed -i "s|ppa.launchpad.net|"`dig +noall +answer A ppa.launchpad.net | awk '{ print $5 }'`"|g" ./.dput.cf && dput -c ./.dput.cf launchpad /tmp/sandboxer-dpkgs/sandboxer_*.changes

