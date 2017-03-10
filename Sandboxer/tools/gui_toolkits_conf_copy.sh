#!/bin/bash

username="$1"
userhome_chroot="$2"
userhome_chroot_hostpath="$3"

# gtkrc files at $HOME directory
for hint in "$HOME/.gtkrc"*
do
  [[ ! -z $hint && -f $hint ]] && 2>/dev/null cp "$hint" "$userhome_chroot_hostpath"
  [[ ! -z $hint && -d $hint ]] && 2>/dev/null cp -rf "$hint" "$userhome_chroot_hostpath"
done

mkdir -p "$userhome_chroot_hostpath/.config"

for hint in "$HOME/.config/gtk"*
do
  [[ ! -z $hint && -f $hint ]] && 2>/dev/null cp "$hint" "$userhome_chroot_hostpath/.config"
  [[ ! -z $hint && -d $hint ]] && 2>/dev/null cp -rf "$hint" "$userhome_chroot_hostpath/.config"
done

exit 0
