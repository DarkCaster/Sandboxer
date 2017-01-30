#/bin/bash

#some ugly test script, to launch executor binary inside bwrap sandboxed env

curdir="$( cd "$( dirname "$0" )" && pwd )"

mkdir -p "$curdir/home"

set -uo pipefail
(exec bwrap \
      --unshare-user \
      --bind "$curdir/../Build/Executor/build" /x \
	  --bind "$curdir/home" /home \
      --ro-bind /usr /usr \
      --ro-bind /lib /lib \
      --ro-bind /lib64 /lib64 \
      --ro-bind /bin /bin \
      --dir /tmp \
      --proc /proc \
      --dev /dev \
      --ro-bind /etc/resolv.conf /etc/resolv.conf \
      --chdir / \
      --unshare-pid \
      --dir /run/user/$(id -u) \
      --setenv XDG_RUNTIME_DIR "/run/user/`id -u`" \
      --file 11 /etc/passwd \
      --file 12 /etc/group \
      /x/executor 0 1 /x control 42) \
    11< <(getent passwd $UID 65534) \
    12< <(getent group $(id -g) 65534)

