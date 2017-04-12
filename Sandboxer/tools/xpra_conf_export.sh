#!/bin/sh

target="$@"
test -z "$target" && target="/executor/control/xpra/xpra_conf.out"

env_list=`printenv -0 | tr -d '\n' | tr '\0' '\n' | sed -n 's|^\([^=]*\)=.*$|\1|p'`

save_var() {
  test -z `echo "$env_list" | grep -x "$1"` && return 1
  eval 'value=`echo "$'"$1"'"`'
  echo "$1=$value" >> "$target"
  return 0
}

#printenv | sort > "$target.env" # debug
save_var "DISABLE_IMSETTINGS"
save_var "DISPLAY"
save_var "GDK_BACKEND"
save_var "GTK_IM_MODULE"
save_var "IMSETTINGS_MODULE"
save_var "MWNOCAPTURE"
save_var "MWNO_RIT"
save_var "MWWM"
save_var "QT_IM_MODULE"
save_var "QT_X11_NO_NATIVE_MENUBAR"
save_var "UBUNTU_MENUPROXY"
save_var "XDG_CURRENT_DESKTOP"
save_var "XDG_SESSION_TYPE"
save_var "XMODIFIERS"

echo "EOF" >> "$target"

exit 0
