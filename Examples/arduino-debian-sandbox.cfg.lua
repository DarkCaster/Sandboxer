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

-- add host /dev mount for acces to arduino devices, not secure!
table.insert(sandbox.setup.mounts,{prio=98,"dev-bind","/dev","/dev_host"})
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyACM0","/dev/ttyACM0"})
table.insert(sandbox.setup.mounts,{prio=99,"symlink","/dev_host/ttyUSB0","/dev/ttyUSB0"})
table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/tmp"}) -- needed for QtCreator online installer to work

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

arduino_install={
  exec="/home/sandboxer/arduino-ide/install.sh",
  path="/home/sandboxer/arduino-ide",
  attach=true,
  pty=false,
}

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
