#!/bin/bash

# download and extract debian image, using docker repository https://hub.docker.com/r/library/debian/
# we will use prepackaged rootfs from docker git repo https://github.com/tianon/docker-brew-debian (it is specified here https://github.com/docker-library/official-images/blob/master/library/debian)

script_dir="$( cd "$( dirname "$0" )" && pwd )"

tag="$1"
[[ -z $tag ]] && echo "usage: download-debian-from-docker-repo.sh <tag>" && exit 1

check_errors () {
  local status="$?"
  local msg="$@"
  if [[ $status != 0 ]]; then
    echo "ERROR: operation finished with error code $status"
    [[ ! -z $msg ]] && echo "$msg"
    exit "$status"
  fi
}

debian_list="/tmp/debian.list"
debian_git="$script_dir/debian_docker_git"

# download file with description
wget -O "$debian_list" https://raw.githubusercontent.com/docker-library/official-images/master/library/debian
check_errors

git_repo=""
tags=""
git_commit=""
directory=""

# parse description
while IFS='' read -r line || [[ -n "$line" ]]; do
  [[ ! -z $git_repo && ! -z $tags && ! -z $git_commit && ! -z $directory ]] && break
  [[ $line =~ ^"GitRepo:"[[:space:]]*(.*)$ ]] && git_repo="${BASH_REMATCH[1]}" && tags="" && git_commit="" && directory="" && continue
  [[ $line =~ ^"Tags:"[[:space:]]*(.*)$ ]] && tags="${BASH_REMATCH[1]}" && continue
  [[ $tags =~ ^.*"$tag".*$ ]] || continue
  [[ $line =~ ^"GitCommit:"[[:space:]]*(.*)$ ]] && git_commit="${BASH_REMATCH[1]}" && continue
  [[ $line =~ ^"Directory:"[[:space:]]*(.*)$ ]] && directory="${BASH_REMATCH[1]}" && continue
done < "$debian_list"
[[ -z $git_repo || -z $tags || -z $git_commit || -z $directory ]] && echo "failed to detect repo parameters for selected tag: $tag" && exit 1

echo "******************************"
echo "selected parameters:"
echo "git_repo   = $git_repo"
echo "tags       = $tags"
echo "git_commit = $git_commit"
echo "directory  = $directory"
echo "******************************"

if [[ ! -d "$debian_git" ]]; then
  git clone $git_repo "$debian_git"
  check_errors
fi

cd "$debian_git"
check_errors

git checkout master
check_errors

git pull
check_errors

git checkout $git_commit
check_errors

mkdir -p "$script_dir/debian_chroot" && cd "$script_dir/debian_chroot"
check_errors

xz -d -c "$debian_git/$directory/rootfs.tar.xz" | tar xf - --no-same-owner --preserve-permissions --exclude='dev'
check_errors
