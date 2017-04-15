#!/bin/dash

username="$1"
userhome_chroot="$2"
userhome_chroot_hostpath="$3"

# gtkrc files at $HOME directory
for hint in "$HOME/.gtkrc"*
do
  test ! -z "$hint" -a -f "$hint" && 2>/dev/null cp "$hint" "$userhome_chroot_hostpath"
  test ! -z "$hint" -a -d "$hint" && 2>/dev/null cp -rf "$hint" "$userhome_chroot_hostpath"
done

mkdir -p "$userhome_chroot_hostpath/.config"

for hint in "$HOME/.config/gtk"*
do
  test ! -z "$hint" -a -f "$hint" && 2>/dev/null cp "$hint" "$userhome_chroot_hostpath/.config" && continue
  if test ! -z "$hint" -a -d "$hint"; then
    dest="$userhome_chroot_hostpath/.config/`basename \"$hint\"`"
    mkdir -p "$dest"
    for sub in "$hint/"*
    do
      test -z "$sub" && continue
      sub_base=`basename "$sub"`
      test "$sub_base" = "bookmarks" -o "$sub_base" = "gtkfilechooser.ini" && continue
      test -f "$sub" && cp "$sub" "$dest" && continue
      test -d "$sub" && cp -rf "$sub" "$dest"
    done
  fi
done

exit 0
