#!/bin/dash

#create essential "/etc" directory for sandbox from host etc
#copy only essential config files that needed for most programs to work.
#try not to copy configs that leak some sensitive system and machine info.

#this script will copy only selected list of files and folders (whitelist)

source_dir="$1"
target_dir="$2"

test -z "$target_dir" && echo "target_dir is empty!" && exit 1

mkdir -p "$target_dir"

copy_file () {
  2>/dev/null \
  cp "$source_dir/$1" "$target_dir/$1"
}

copy_glob () {
  2>/dev/null \
  cp -rf "$source_dir/$1"* "$target_dir"
}

copy_glob "alternatives"
copy_glob "alias"
copy_glob "bonobo"
copy_glob "ca-certificates"
copy_glob "bash"
copy_glob "cracklib"
copy_glob "dictionaries"
copy_glob "emacs"
copy_glob "firefox"
copy_glob "fonts"
copy_glob "gconf"
copy_glob "ghostscript"
copy_glob "gnome"
copy_glob "groff"
copy_glob "gss"
copy_glob "gtk-"
copy_glob "java"
copy_glob "ld.so"
copy_glob "libnl"
copy_glob "mc"
copy_glob "openal"
copy_glob "perl"
copy_glob "pki"
copy_glob "profile.d"
copy_glob "purple"
copy_glob "python"
copy_glob "sound"
copy_glob "ssl"
copy_glob "terminfo"
copy_glob "timidity"
copy_glob "vim"
copy_glob "wildmidi"
copy_glob "xdg"
copy_glob "xml"
copy_glob "debian_version"
copy_glob "zsh"
copy_glob "security"
copy_glob "pulse"
copy_glob "host"
copy_glob "kde4"
copy_glob "csh"
copy_glob "less"
copy_glob "xpra"

copy_file "drirc"
copy_file "environment"
copy_file "gai.conf"
copy_file "HOSTNAME"
copy_file "libao.conf"
copy_file "lsb-release"
copy_file "ltrace.conf"
copy_file "nanorc"
copy_file "bindresvport.blacklist"
copy_file "os-release"
copy_file "yp.conf"
copy_file "wgetrc"
copy_file "vdpau_wrapper.cfg"
copy_file "termcap"
copy_file "profile"
copy_file "protocols"
copy_file "nsswitch.conf"
copy_file "nscd.conf"
copy_file "networks"
copy_file "mime.types"
copy_file "manpath.config"
copy_file "ksh.kshrc"
copy_file "krb5.conf"
copy_file "inputrc"
copy_file "freshwrapper.conf"
copy_file "ethers"
copy_file "DIR_COLORS"
copy_file "dialogrc"
copy_file "asound-pulse.conf"
copy_file "alsa-pulse.conf"
copy_file "adjtime"

rm -f "$target_dir/mtab"
ln -s "/proc/self/mounts" "$target_dir/mtab"

exit 0
