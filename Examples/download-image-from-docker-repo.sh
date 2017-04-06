#!/bin/bash

# simple script to download and extract rootfs image from docker git repository
# by parsing description file from https://github.com/docker-library/official-images/tree/master/library/<target>
# then, it perform clone of target git repo with rootfs archives, checkout to target commit and extract rootfs archive
# TODO: direct download target rootfs.tar.xz from selected github repo and commit by using raw.githubusercontent.com

script_dir="$( cd "$( dirname "$0" )" && pwd )"

target="$1"
[[ -z $target ]] && echo "usage: download-image-from-docker-repo.sh <target> <tag> [rootfs archive name] [chroot extract dir] [docker git repo dir]" && exit 1

tag="$2"
[[ -z $tag ]] && echo "usage: download-image-from-docker-repo.sh <target> <tag> [rootfs archive name] [chroot extract dir] [docker git repo dir]" && exit 1

rootfs="$3"
[[ -z $rootfs ]] && rootfs="rootfs.tar.xz"

output="$4"
[[ -z $output ]] && output="$script_dir/${target}_chroot"

image_git="$5"
[[ -z $image_git ]] && image_git="$script_dir/${target}_docker_repo"

check_errors () {
  local status="$?"
  local msg="$@"
  if [[ $status != 0 ]]; then
    echo "ERROR: operation finished with error code $status"
    [[ ! -z $msg ]] && echo "$msg"
    exit "$status"
  fi
}

[[ ! -d "$output" ]] || check_errors "directory $output already exist!"

image_list=`mktemp --tmpdir "$target.XXXXXX.list"`

# download description
wget -O "$image_list" "https://raw.githubusercontent.com/docker-library/official-images/master/library/$target"
check_errors

git_repo=""
tags=""
git_commit=""
git_fetch=""
directory=""

# parse description
while IFS='' read -r line || [[ -n "$line" ]]; do
  [[ -z $line && ! -z $git_repo && ! -z $tags && ! -z $git_commit && ! -z $directory ]] && break
  [[ $line =~ ^"GitRepo:"[[:space:]]*(.*)$ ]] && git_repo="${BASH_REMATCH[1]}" && continue
  [[ $line =~ ^"Directory:"[[:space:]]*(.*)$ ]] && directory="${BASH_REMATCH[1]}" && continue
  if [[ $line =~ ^"Tags:"([[:space:]].*)$ ]]; then
    tags="${BASH_REMATCH[1]}"
    [[ $tags =~ ^.*[[:space:]]"$tag"(","|$).* ]] || tags=""
    git_commit=""
    git_fetch=""
    continue
  fi
  [[ $line =~ ^"GitCommit:"[[:space:]]*(.*)$ ]] && git_commit="${BASH_REMATCH[1]}" && continue
  [[ $line =~ ^"GitFetch:"[[:space:]]*"refs/heads/"(.*)$ ]] && git_fetch="${BASH_REMATCH[1]}" && continue
done < "$image_list"

rm "$image_list"

echo "******************************"
echo "parameters parsed from list:"
echo "git_repo   = $git_repo"
echo "tags       =$tags"
echo "git_fetch  = $git_fetch"
echo "git_commit = $git_commit"
echo "directory  = $directory"
echo "******************************"

[[ -z $git_repo || -z $tags || -z $git_commit || -z $directory ]] && echo "failed to detect repo parameters for selected tag: $tag" && exit 1

if [[ ! -d "$image_git" ]]; then
  mkdir -p "$image_git" && cd "$image_git"
  check_errors
  git init
  check_errors
  git remote add ext "$git_repo"
  check_errors
fi

cd "$image_git"
check_errors

if [[ ! -z `git branch` ]]; then
  git checkout -f --orphan "${target}_${tag}_dump"
  check_errors
  git for-each-ref --format '%(refname:short)' refs/heads | xargs git branch -D
  check_errors
fi

git fetch -f --all
check_errors

git checkout -f "$git_commit" || git_commit=""

if [[ -z $git_commit && ! -z $git_fetch ]]; then
  echo "failed to checkout requested commit, trying to use branch $git_fetch instead"
  git branch -f "${target}_${tag}" "ext/$git_fetch"
  check_errors
  git checkout -f "${target}_${tag}"
  check_errors
elif [[ -z $git_commit ]]; then
  echo "failed to prepare repo"
  exit 1
fi

mkdir -p "$output" && cd "$output"
check_errors

xz -d -c "$image_git/$directory/$rootfs" | tar xf - --no-same-owner --preserve-permissions --exclude='dev'
check_errors
