-- various IDEs and other development-tools collection that I'm using.
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
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"pulse")

-- remove some unneded mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- /sys mount is needed for adb\fastboot to work, uncomment next line to disable it
-- loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

-----------------
-- host mounts --
-----------------

-- directory with ide/tools installers, "installs" dir must be located at the same path as this config file
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
-- main host-storage
table.insert(sandbox.setup.mounts,{prio=99,"bind-try","/mnt/data","/mnt/data"})
-- "Trash" directory at /mnt/data mountpoint
table.insert(sandbox.setup.commands,{'[[ -e "/mnt/data/.Trash-${cfg[tunables.uid]}" && ! -L "${cfg[tunables.auto.user_path]}/.local/share/Trash" ]] && mkdir -p "${cfg[tunables.auto.user_path]}/.local/share" && rm -rf "${cfg[tunables.auto.user_path]}/.local/share/Trash" && ln -s "/mnt/data/.Trash-${cfg[tunables.uid]}" "${cfg[tunables.auto.user_path]}/.local/share/Trash"; true'})
-- mount host /dev into separate directory
table.insert(sandbox.setup.mounts,{prio=98,"dev-bind","/dev","/dev_host"})
-- symlinks to usb-uart converter devices for arduino IDE and other tools
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyACM0","/dev/ttyACM0"})
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyUSB0","/dev/ttyUSB0"})
-- make usb devices available for sandbox
table.insert(sandbox.setup.mounts,{prio=98,"dev-bind","/dev/bus/usb","/dev/bus/usb"})
-- separate /tmp mount needed for QtCreator online installer to work
table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/tmp"})

-- profiles for IDEs and other helper tools supported with this sandbox

shell.term_orphans=true --terminale all running processes when exiting shell profile, comment thils line if needed

arduino={
  exec="/home/sandboxer/arduino-ide/arduino",
  path="/home/sandboxer/arduino-ide",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Arduino IDE (in sandbox)",
    comment = "Arduino IDE, sandbox uid "..config.sandbox_uid,
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

-- android sdk manager from https://developer.android.com/studio
android_studio_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  android_studio=\"$HOME/android-studio\"; \
  [ -d \"$android_studio\" ] && echo \"Do not attempt to remove old android-studio directory\" && exit 1; \
  cd $HOME; \
  [ -d \"$android_studio\" ] && echo \"Removing directory $android_studio\" && rm -r \"$android_studio\"; \
  img=`find ./installs -name \"android-studio-ide-*-linux.tar.gz\"|sort -V|tail -n1` && ( gunzip -c \"$img\" | tar xf - ); \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

android_studio_install_tarxz=android_studio_install
android_studio_install_targz=android_studio_install

android_studio={
  exec="/home/sandboxer/android-studio/bin/studio.sh",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop={
    name = "Android Studio (in sandbox)",
    comment = "Android Studio, sandbox uid "..config.sandbox_uid,
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
    name = "QtCreator Maintenance Tool (in sandbox)",
    comment = "QtCreator Maintenance Tool, sandbox uid "..config.sandbox_uid,
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
    name = "QtCreator IDE (in sandbox)",
    comment = "QtCreator IDE, sandbox uid "..config.sandbox_uid,
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
  pty=false,
  exclusive=true,
}

stm32cubeprog={
  exec="/home/sandboxer/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32CubeProgrammer",
  path="/home/sandboxer/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  desktop={
    name = "STM32CubeProgrammer",
    comment = "STM32CubeProgrammer, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/STMicroelectronics/STM32Cube/STM32CubeProgrammer/util/Programmer.ico"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;Qt;Electronics",
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

minicom_ttyUSB0_38400={
  exec="/usr/bin/minicom",
  path="/home/sandboxer",
  args={"-c","off","38400_8N1","-D","/dev/ttyUSB0"},
  term_signal=defaults.signals.SIGTERM,
  env_unset={"TERM"},
  env_set={{"TERM",os.getenv("TERM")}},
  attach=true,
  pty=true,
  exclusive=true,
}
