-- various IDEs and other development-tools collection that I'm using, including tools for embedded development
-- for better integration all the tools was combined in the single sandbox based on external debian chroot (prepared by debian-setup.cfg.lua)
-- some system paths from host-system exposed into the sandbox.

-- for running electron/chromium based apps (like vscode, or atom) on some systems you may need to enable unprivileged user namespaces systemwide with "sysctl kernel.unprivileged_userns_clone=1"
-- more info at:
-- https://github.com/microsoft/vscode/issues/81056
-- https://security.stackexchange.com/questions/209529/what-does-enabling-kernel-unprivileged-userns-clone-do

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-ide-"..config.uid)
  -- tmp directory for /tmp mount, tmpfs may be too small sometimes
  tunables.custom_tmp_path=loader.path.combine(tunables.datadir,"root_tmp")
  defaults.recalculate_orig()
end

defaults.recalculate()


-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"pulse")

-- remove some unneded mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- /sys mount is needed for adb\fastboot to work, uncomment next line to disable it
-- loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)

-- /dev/dri mount is needed for hw video acceleration to work
-- loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- modify PATH env
path_env="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
table.insert(sandbox.setup.env_set,{"PATH",path_env})

-- needed for flutter, choose your chromium-based browser location
-- table.insert(sandbox.setup.env_set,{"CHROME_EXECUTABLE","/usr/bin/chromium"})
table.insert(sandbox.setup.env_set,{"CHROME_EXECUTABLE","/usr/bin/microsoft-edge"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

-----------------
-- host mounts --
-----------------

-- directory with ide/tools installers, "installs" dir must be located at the same path as this config file
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
-- main host-storage
table.insert(sandbox.setup.mounts,{prio=99,"bind-try","/mnt/data","/mnt/data"})
-- "Trash" directory at /mnt/data mountpoint, you may want to install libglib2.0-bin package with "gio" binary to allow move files to trash in vscode
table.insert(sandbox.setup.commands,{'[[ -e "/mnt/data/.Trash-${cfg[tunables.uid]}" && ! -L "${cfg[tunables.auto.user_path]}/.local/share/Trash" ]] && mkdir -p "${cfg[tunables.auto.user_path]}/.local/share" && rm -rf "${cfg[tunables.auto.user_path]}/.local/share/Trash" && ln -s "/mnt/data/.Trash-${cfg[tunables.uid]}" "${cfg[tunables.auto.user_path]}/.local/share/Trash"; true'})
-- real /tmp directory for more space
table.insert(sandbox.setup.commands,{'mkdir -p "${cfg[tunables.custom_tmp_path]}"'})
table.insert(sandbox.setup.mounts,{prio=99,"bind",tunables.custom_tmp_path,"/tmp"})
-- tmpfs /tmp mount, disabled
-- table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/tmp"})
-- mount host /dev into separate directory
table.insert(sandbox.setup.mounts,{prio=98,"dev-bind","/dev","/dev_host"})
-- symlinks to usb-uart converter devices for arduino IDE and other tools
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyACM0","/dev/ttyACM0"})
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyUSB0","/dev/ttyUSB0"})
-- symlink to /dev/kvm
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/kvm","/dev/kvm"})
-- make usb devices available for sandbox
table.insert(sandbox.setup.mounts,{prio=98,"dev-bind-try","/dev/bus/usb","/dev/bus/usb"})
-- system dbus socket
table.insert(sandbox.setup.mounts,{prio=99,"bind-try","/run/dbus","/run/dbus"})

-- try running android-stutio avd devices from tmpfs, especially needed for the latest android versions, it just unusable on HDD
-- you will need a lot of ram, and also need to recreate avd device each time
-- commend out following 2 lines if you have a fast SSD or if you want to have permanent avds
table.insert(sandbox.setup.mounts,{prio=99,"dir","/home/sandboxer/.android/avd"})
table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/home/sandboxer/.android/avd"})

-- profiles for IDEs and other helper tools supported with this sandbox

-- shell.term_orphans=true --terminale all running processes when exiting shell profile, comment thils line if needed

arduino={
  exec="/home/sandboxer/arduino-ide/arduino",
  path="/home/sandboxer/arduino-ide",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Arduino IDE",
    comment = "Arduino IDE (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/.local/share/icons/hicolor/128x128/apps/arduino-arduinoide.png"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Electronics",
  },
}

arduino_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  arduino_dir=\"$HOME/arduino-ide\"; \
  [ -d \"$arduino_dir\" ] && cd \"$arduino_dir\" && echo \"Uninstalling old arduino installation\" && ./uninstall.sh; \
  cd $HOME; \
  [ -d \"$arduino_dir\" ] && echo \"Removing directory $arduino_dir\" && rm -r \"$arduino_dir\"; \
  img=`find ./installs -name \"arduino-*-linux*.tar.xz\"|sort -V|tail -n1` && ( xz -d -c \"$img\" | tar xf - ) && mv \"$HOME/\"arduino-* \"$arduino_dir\" && echo \"Installing new arduino installation from $img\" && cd \"$arduino_dir\" && ./install.sh; \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

arduino_install_targz=arduino_install
arduino_install_tarxz=arduino_install

arduino2={
  exec="/home/sandboxer/arduino-ide/arduino-ide",
  path="/home/sandboxer/arduino-ide",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Arduino IDE v2",
    comment = "Arduino IDE (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/arduino-ide/resources/app/resources/icons/512x512.png"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Electronics",
  },
}

arduino_2_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  arduino_dir=\"$HOME/arduino-ide\"; \
  cd $HOME; \
  [ -d \"$arduino_dir\" ] && echo \"Removing directory $arduino_dir\" && rm -r \"$arduino_dir\"; \
  img=`find ./installs -name \"arduino-*_Linux*.zip\"|sort -V|tail -n1` && unzip \"$img\" -d \"$arduino_dir\"; \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

arduino_cli_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  arduino_dir=\"$HOME/arduino-cli\"; \
  cd $HOME; \
  [ -d \"$arduino_dir\" ] && echo \"Removing directory $arduino_dir\" && rm -r \"$arduino_dir\"; \
  img=`find \"$HOME/installs\" -name \"arduino-cli_*_Linux*.tar.gz\"|sort -V|tail -n1` && mkdir \"$arduino_dir\" && cd \"$arduino_dir\" && ( gunzip -c \"$img\" | tar xf - ); \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

arduino_cli={
  exec="/home/sandboxer/arduino-cli/arduino-cli",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=false,
}

-- android sdk manager from https://developer.android.com/studio
android_studio_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  android_studio=\"$HOME/android-studio\"; \
  [ -d \"$android_studio\" ] && echo \"Do not attempt to remove old android-studio directory\" && exit 1; \
  cd $HOME; \
  [ -d \"$android_studio\" ] && echo \"Removing directory $android_studio\" && rm -r \"$android_studio\"; \
  img=`find ./installs -name \"android-studio-*-linux.tar.gz\"|sort -V|tail -n1` && echo \"extracting $img\" && ( gunzip -c \"$img\" | tar xf - ); \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

android_studio={
  exec="/home/sandboxer/android-studio/bin/studio",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop={
    name = "Android Studio",
    comment = "Android Studio (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/android-studio/bin/studio.png"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Android",
  },
}

qtcreator_installer={
  exec="/home/sandboxer/Qt/MaintenanceTool",
  path="/home/sandboxer/Qt",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop={
    name = "QtCreator Maintenance Tool",
    comment = "QtCreator Maintenance Tool (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/Qt/QtIcon.png"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Qt",
  },
}

qtcreator={
  exec="/home/sandboxer/Qt/Tools/QtCreator/bin/qtcreator",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  desktop={
    name = "QtCreator IDE",
    comment = "QtCreator (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/.local/share/icons/hicolor/128x128/apps/QtProject-qtcreator.png"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Qt;Electronics",
  },
}

qt_bootstrap={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  target=\"/tmp/qt-bootstrap\"; \
  [ -d \"$target\" ] && rm -rf \"$target\"; \
  mkdir -p \"$target\"; \
  archive=`find \"$HOME/installs\" -name \"qt-unified-linux-*-online.run\"|sort -V|tail -n1` && ( cd \"$target\" && cp \"$archive\" ./runme && chmod 755 ./runme ); \
  cd \"$target\" && ./runme; \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

stm32cubeide_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  target=\"/tmp/stm32cubeide\"; \
  [ -d \"$target\" ] && rm -rf \"$target\"; \
  mkdir -p \"$target\"; \
  archive=`find \"$HOME/installs\" -name \"*st-stm32cubeide*.zip\"|sort -V|tail -n1` && ( cd \"$target\" && unzip \"$archive\" ); \
  cd \"$target\" && chmod 755 \"$target/st-stm32cubeide\"*.sh && \"$target/st-stm32cubeide\"*.sh; \
  cd ~/st ;\
  installation=`find . -type d -name \"stm32cubeide_*\"|sort -V|tail -n1` ;\
  rm -fv cubeide && ln -s \"$installation\" cubeide ;\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

stm32cubeide={
  exec="/home/sandboxer/st/cubeide/stm32cubeide",
  path="/home/sandboxer/st/cubeide",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  env_set={{"PATH","/home/sandboxer/stlink-server:"..path_env}},
  desktop={
    name = "STM32CubeIDE",
    comment = "STM32CubeIDE, (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"home/sandboxer/st/cubeide/icon.xpm"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Qt;Electronics",
  },
}

stm32cubeprog_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  target=\"/tmp/stm32cubeprog\"; \
  [ -d \"$target\" ] && rm -rf \"$target\"; \
  mkdir -p \"$target\"; \
  archive=`find \"$HOME/installs\" -name \"*stm32cubeprg-lin*.zip\"|sort -V|tail -n1` && ( cd \"$target\" && unzip \"$archive\" ); \
  cd \"$target\" && \"$target/SetupSTM32CubeProgrammer-2.8.0.linux\"; \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

stm32cubeprog={
  exec="/home/sandboxer/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32CubeProgrammer",
  path="/home/sandboxer/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  env_set={{"PATH","/home/sandboxer/stlink-server:"..path_env}},
  desktop={
    name = "STM32CubeProgrammer",
    comment = "STM32CubeProgrammer (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/STMicroelectronics/STM32Cube/STM32CubeProgrammer/util/Programmer.ico"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Qt;Electronics",
  },
}

stlinkserver_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  target=\"/home/sandboxer/stlink-server\"; \
  [ -d \"$target\" ] && rm -rf \"$target\"; \
  mkdir -p \"$target\"; \
  extract=\"/tmp/stlink-server\"; \
  [ -d \"$extract\" ] && rm -rf \"$extract\"; \
  mkdir -p \"$extract\"; \
  archive=`find \"$HOME/installs\" -name \"*st-link-server*.zip\"|sort -V|tail -n1` && ( cd \"$extract\" && unzip \"$archive\" ); \
  exe=`find \"$extract\" -name \"stlink-server.*\"|sort -V|tail -n1` && ( cd \"$target\" && chmod 755 \"$exe\" && cp \"$exe\" stlink-server ); \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

-- you may need to install and configure android studio into this sandbox by running:
-- sandboxer ide-debian-sandbox.cfg.lua android_studio_install; sandboxer ide-debian-sandbox.cfg.lua android_studio
flutter_install={
  exec="/bin/bash",
  path="/tmp",
  args={"-c","rm -rf $HOME/flutter && img=`find $HOME/installs -name \"flutter_linux_*.tar.xz\"|sort|tail -n1` && echo \"extracting $img\" && tar xf \"$img\" && mv /tmp/flutter $HOME/flutter && \
        echo \"modifying PATH env var\" && ( grep -qxF 'PATH=\"$HOME/flutter/bin:$PATH\"' $HOME/.profile || echo 'PATH=\"$HOME/flutter/bin:$PATH\"' >> $HOME/.profile )"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

go_install={
  exec="/bin/bash",
  path="/tmp",
  args={"-c","rm -rf $HOME/go_dist && img=`find $HOME/installs -name \"go*linux-amd64.tar.gz\"|sort|tail -n1` && ( gunzip -c \"$img\" | tar xf - ) && mv /tmp/go $HOME/go_dist"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

vscode_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/VSCode && img=`find ./installs -name \"code-stable-*.tar.gz\"|sort|tail -n1` && ( gunzip -c \"$img\" | tar xvf - ) && mv $HOME/VSCode-* $HOME/VSCode"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

vscode={
  exec="/home/sandboxer/VSCode/code",
  path="/home/sandboxer/VSCode",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  term_orphans=true,
  attach=false,
  pty=false,
  env_set={{"GOROOT","/home/sandboxer/go_dist"}},
  desktop={
    name = "Visual Studio Code",
    comment = "VSCode (IDE sandbox)",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/VSCode/resources/app/resources/linux/code.png"),
    field_code="%f",
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;",
    mimetype = "text/x-vscode-workspace-sandbox",
    mime =
    {
      vscode_workspace='<?xml version="1.0" encoding="UTF-8"?>\
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">\
      <mime-type type="text/x-vscode-workspace-sandbox">\
      <comment>VSCode Workspace</comment>\
      <icon name="text-x-source"/>\
      <glob-deleteall/>\
      <glob pattern="*.code-workspace"/>\
      </mime-type>\
      </mime-info>'
    },
  },
}

vscode_system={
  exec="/usr/share/code/code",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  term_orphans=true,
  attach=false,
  pty=false,
  env_set={{"GOROOT","/home/sandboxer/go_dist"}},
  desktop={
    name = "Visual Studio Code",
    comment = "VSCode (IDE sandbox)",
    icon = loader.path.combine(tunables.chrootdir,"/usr/share/pixmaps/vscode.png"),
    field_code="%f",
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;",
    mimetype = "text/x-vscode-workspace-sandbox",
    mime =
    {
      vscode_workspace='<?xml version="1.0" encoding="UTF-8"?>\
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">\
      <mime-type type="text/x-vscode-workspace-sandbox">\
      <comment>VSCode Workspace</comment>\
      <icon name="text-x-source"/>\
      <glob-deleteall/>\
      <glob pattern="*.code-workspace"/>\
      </mime-type>\
      </mime-info>'
    },
  },
}

openscad={
  exec="/home/sandboxer/OpenSCAD/AppRun",
  path="/home/sandboxer/OpenSCAD",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop={
    name = "OpenSCAD (in sandbox)",
    comment = "OpenSCAD, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/OpenSCAD/.DirIcon"),
    terminal = false,
    startupnotify = false,
    categories="Graphics;",
  },
}

openscad_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/OpenSCAD && img=`find ./installs -name \"OpenSCAD-*.AppImage\"|sort -V|tail -n1` && chmod 755 $img && $img --appimage-extract && mv $HOME/squashfs-root $HOME/OpenSCAD"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

-- configuration util for mikrotik devices, you will need to install wine64 and icoutils
winbox64_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  env_set={{"WINEPREFIX","/home/sandboxer/winbox/wineroot"}},
  args={"-c", "\
  target=\"/home/sandboxer/winbox\"; \
  [ -d \"$target\" ] && rm -rf \"$target\"; \
  mkdir -p \"$target\"; \
  wget -O \"$target/winbox64.exe\" \"https://mt.lv/winbox64\"; \
  wrestool -x -t 14 \"$target/winbox64.exe\" -o \"$target/icon.ico\"; \
  wine64 wineboot"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

winbox64={
  exec="/usr/bin/wine64",
  path="/home/sandboxer/winbox",
  env_set={{"WINEPREFIX","/home/sandboxer/winbox/wineroot"}},
  args={"winbox64.exe"},
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  exclusive=false,
  desktop={
    name = "Winbox",
    comment = "MikroTik router configuration utility",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/winbox/icon.ico"),
    terminal = false,
    startupnotify = false,
    categories="Network;System;",
  },
}

minicom_ttyACM0={
  exec="/usr/bin/minicom",
  path="/home/sandboxer",
  args={"-c","off","115200_8N1","-D","/dev/ttyACM0"},
  term_signal=defaults.signals.SIGTERM,
  env_unset={"TERM"},
  env_set={{"TERM",os.getenv("TERM")}},
  attach=true,
  pty=true,
  exclusive=true,
}

minicom_ttyUSB0={
  exec="/usr/bin/minicom",
  path="/home/sandboxer",
  args={"-c","off","115200_8N1","-D","/dev/ttyUSB0"},
  term_signal=defaults.signals.SIGTERM,
  env_unset={"TERM"},
  env_set={{"TERM",os.getenv("TERM")}},
  attach=true,
  pty=true,
  exclusive=true,
}
