#!/bin/bash

script_dir="$( cd "$( dirname "$0" )" && pwd )"
self=`basename "$0"`
[[ ! -e $script_dir/$self ]] && echo "script_dir detection failed. cannot proceed!" && exit 1
script_file=`readlink "$script_dir/$self"`
[[ ! -z $script_file ]] && script_dir=`realpath \`dirname "$script_file"\``

show_usage() {
  echo "usage: desktop-file-creator.sh <config file> <exec profile> <action: install\uninstall> [true, to create separate \"sandboxer\" startmenu category]"
  exit 1
}

config="$1"
[[ -z $config ]] && show_usage
config=`realpath -s "$config"`
[[ ! -f $config ]] && echo "config file missing" && exit 1
shift 1

profile="$1"
[[ -z $profile ]] && show_usage
shift 1

action="$1"
[[ -z $action ]] && show_usage
if [[ $action != install && $action != uninstall ]]; then
 echo "action param incorrect" && exit 1
fi
shift 1

create_cat="$1"
[[ -z $create_cat ]] && create_cat="false"
shift $#

includes_dir="$script_dir/includes"
tools_dir="$script_dir/tools"

#activate some loadables
. "$includes_dir/loadables-helper.bash.in"

#generate uid for given config file
[[ ! -e $config ]] && echo "config file not found: $config" && exit 1
config_uid=`realpath -s "$config" | md5sum -t | cut -f1 -d" "`

#user id and group id
uid=`id -u`
gid=`id -g`

#temp directory
tmp_dir="$TMPDIR"
[[ -z $tmp_dir || ! -d $tmp_dir ]] && tmp_dir="/tmp"


. "$includes_dir/find-lua-helper.bash.in" "$script_dir/BashLuaHelper" "$script_dir/../BashLuaHelper"
. "$bash_lua_helper" "$config" -e profile -b "$script_dir/sandboxer.pre.lua" -a "$script_dir/sandboxer.post.lua" -o "$profile" -o "$HOME" -o "$script_dir" -o "$curdir" -o "$config_uid" -o "$tmp_dir" -o "$tmp_dir/sandbox-$config_uid" -o "$uid" -o "$gid"

[[ "${#cfg[@]}" = 0 ]] && echo "can't find config storage variable populated by bash_lua_helper. bash_lua_helper failed!" && exit 1

tmp_dir=`mktemp -d -t desktop-file-creator-XXXXXXXX`

if [ "$create_cat" = "true" ] && [ "$action" = "install" ]; then
  echo "creating 'Sandboxer Applications' submenu and 'Sandboxer' category"

  #create and install directory file
  tmp_dirfile="$tmp_dir/sandboxer.directory"
  echo "#!/usr/bin/env xdg-open" >> "$tmp_dirfile"
  echo "[Desktop Entry]" >> "$tmp_dirfile"
  echo "Version=1.0" >> "$tmp_dirfile"
  echo "Type=Directory" >> "$tmp_dirfile"
  echo "Name=Sandboxed Applications" >> "$tmp_dirfile"
  echo "Icon=applications-other" >> "$tmp_dirfile"

  mkdir -p "$HOME/.local/share/desktop-directories"
  mv "$tmp_dirfile" "$HOME/.local/share/desktop-directories"

  #create and install menu file
  tmp_menufile="$tmp_dir/sandboxer.menu"
  cat << EOF > "$tmp_menufile"
  <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
  <Menu>
  <Name>Applications</Name>
  <Menu>
  <Name>Sandboxed Applications</Name>
  <Directory>sandboxer.directory</Directory>
  <Include>
  <Category>Sandboxer</Category>
  </Include>
  </Menu>
  </Menu>
  EOF

  #TODO: for now only generic and mate applications-merged menus supported, add other DE support if needed
  mkdir -p "$HOME/.config/menus/applications-merged"
  test ! -e "$HOME/.config/menus/mate-applications-merged" && ln -s applications-merged "$HOME/.config/menus/mate-applications-merged"
  cp "$tmp_menufile" "$HOME/.config/menus/applications-merged"
  mv "$tmp_menufile" "$HOME/.config/menus/mate-applications-merged"
fi

if check_lua_export profile.desktop.name; then
  if [[ $action = install ]]; then
    echo "creating desktop file for profile $profile"
    tmp_desktop="$tmp_dir/${cfg[profile.desktop.filename]}"
    # create desktop file
    echo "#!/usr/bin/env xdg-open" >> "$tmp_desktop"
    echo "[Desktop Entry]" >> "$tmp_desktop"
    echo "Type=Application" >> "$tmp_desktop"
    echo "Name=${cfg[profile.desktop.name]}" >> "$tmp_desktop"
    echo "GenericName=sandboxer.sh \"$config\" \"$profile\"" >> "$tmp_desktop"
    echo "Comment=${cfg[profile.desktop.comment]}" >> "$tmp_desktop"
    echo "Exec=sandboxer.sh \"$config\" \"$profile\"" >> "$tmp_desktop"
    echo "Icon=${cfg[profile.desktop.icon]}" >> "$tmp_desktop"
    if [[ $create_cat = true ]]; then
      echo "Categories=Sandboxer;${cfg[profile.desktop.categories]}" >> "$tmp_desktop"
    else
      echo "Categories=${cfg[profile.desktop.categories]}" >> "$tmp_desktop"
    fi
    if [[ ! -z ${cfg[profile.desktop.mimetype]} ]]; then
      echo "MimeType=${cfg[profile.desktop.mimetype]}" >> "$tmp_desktop"
    fi
    echo "Terminal=${cfg[profile.desktop.terminal]}" >> "$tmp_desktop"
    echo "StartupNotify=${cfg[profile.desktop.startupnotify]}" >> "$tmp_desktop"
    chmod 755 "$tmp_desktop"
    [[ -e $HOME/.local/share/applications/${cfg[profile.desktop.filename]} ]] && rm "$HOME/.local/share/applications/${cfg[profile.desktop.filename]}"
    mkdir -p "$HOME/.local/share/applications"
    mv "$tmp_desktop" "$HOME/.local/share/applications"
  else
    echo "removing desktop file for profile $profile"
    rm "$HOME/.local/share/applications/${cfg[profile.desktop.filename]}"
  fi
fi

if check_lua_export profile.desktop.mime_list; then
  mkdir -p "$HOME/.local/share/mime/packages"
  mkdir -p "$HOME/.local/share/applications"
  if [[ $action = install ]]; then
    echo "installing mime packages for profile $profile"
    for target in ${cfg[profile.desktop.mime_list]}
    do
      echo "installing $target package"
      echo "${cfg[profile.desktop.mime.$target]}" > "$HOME/.local/share/mime/packages/$target.xml"
    done
  else
    echo "removing mime packages for profile $profile"
    for target in ${cfg[profile.desktop.mime_list]}
    do
      echo "removing $target package"
      rm "$HOME/.local/share/mime/packages/$target.xml"
    done
  fi
  echo "running update-mime-database"
  update-mime-database "$HOME/.local/share/mime"
  echo "running update-desktop-database"
  update-desktop-database "$HOME/.local/share/applications"
fi

rm -rf "$tmp_dir"
