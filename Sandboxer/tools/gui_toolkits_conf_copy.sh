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
  [[ ! -z $hint && -f $hint ]] && 2>/dev/null cp "$hint" "$userhome_chroot_hostpath/.config" && continue
  if [[ ! -z $hint && -d $hint ]]; then
    dest="$userhome_chroot_hostpath/.config/`basename \"$hint\"`"
    mkdir -p "$dest"
    for sub in "$hint/"*
    do
      [[ -z $sub ]] && continue
      sub_base=`basename "$sub"`
      [[ $sub_base = bookmarks || $sub_base = gtkfilechooser.ini ]] && continue
      [[ -f $sub ]] && cp "$sub" "$dest" && continue
      [[ -d $sub ]] && cp -rf "$sub" "$dest"
    done
  fi
done

exit 0
