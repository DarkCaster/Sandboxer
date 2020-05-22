-- example config for freecad sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-freecad")
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
--loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
--loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- add host mounts, readonly
table.insert(sandbox.setup.mounts,{prio=99,"bind","/mnt/data","/mnt/data"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

freecad={
  exec="/home/sandboxer/Freecad/AppRun",
  path="/home/sandboxer/Freecad",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop={
    name = "Freecad (in sandbox)",
    comment = "Freecad, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/Freecad/.DirIcon"),
    terminal = false,
    startupnotify = false,
    categories="Graphics;",
  },
}

freecad_install_appimage={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/Freecad && img=`find ./installs -name \"FreeCAD_*.AppImage\"|sort -V|tail -n1` && chmod 755 $img && $img --appimage-extract && mv $HOME/squashfs-root $HOME/Freecad"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

freecad_install=freecad_install_appimage

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

openscad_install_appimage={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/OpenSCAD && img=`find ./installs -name \"OpenSCAD-*.AppImage\"|sort -V|tail -n1` && chmod 755 $img && $img --appimage-extract && mv $HOME/squashfs-root $HOME/OpenSCAD"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

openscad_install=openscad_install_appimage
