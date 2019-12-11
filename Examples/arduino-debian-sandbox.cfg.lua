-- experimental, not for regular use!
-- example config for arduino-ide sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-arduino")
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"pulse")

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})

-- add host /dev mount for acces to arduino devices, not secure!
table.insert(sandbox.setup.mounts,{prio=98,"dev-bind","/dev","/dev_host"})
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyACM0","/dev/ttyACM0"})
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyUSB0","/dev/ttyUSB0"})
table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/tmp"}) -- needed for QtCreator online installer to work

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

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

arduino_install_tarxz={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", "\
  arduino_dir=\"$HOME/arduino-ide\"; \
  [ -d \"$arduino_dir\" ] && cd \"$arduino_dir\" && echo \"uninstalling old arduino installation\" && ./uninstall.sh; \
  cd $HOME; \
  [ -d \"$arduino_dir\" ] && echo \"Removing directory $arduino_dir\" && rm -r \"$arduino_dir\"; \
  img=`find ./installs -name \"arduino-*-linux*.tar.xz\"|sort -V|tail -n1` && ( xz -d -c \"$img\" | tar xf - ) && mv \"$HOME/\"arduino-* \"$arduino_dir\" && echo \"Installing new arduino installation from $img\" && cd \"$arduino_dir\" && ./install.sh; \
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

arduino_install_targz=arduino_install_tarxz

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
