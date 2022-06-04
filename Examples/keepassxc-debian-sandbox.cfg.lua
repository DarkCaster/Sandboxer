-- example config for KeePassXC sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- redefine defaults.recalculate function, that will be called by base config
tunables.datadir=loader.path.combine(loader.workdir,"userdata-keepassxc")
defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- redefine sandbox.features table
sandbox.features={
  "x11host",
  "envfix",
}

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- try to mount directory "secrets" with password-databases (should be located at the same directory as this config file)
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"secrets"),"/home/sandboxer/secrets"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"export"),"/home/sandboxer/export"})
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})

-- add bwrap unshare-net option to cut off sandbox from network
table.insert(sandbox.bwrap,defaults.bwrap.unshare_net)

-- add bwrap unshare_ipc option, remove following 2 lines if dropbox GUI is not displaying properly
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)
table.insert(sandbox.bwrap,defaults.bwrap.unshare_ipc)

keepassxc={
  exec="/home/sandboxer/keepassxc/AppRun",
  path="/home/sandboxer/keepassxc",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "KeePassXC (in sandbox)",
    generic_name = "Password Manager",
    comment = "KeePassXC Password Manager, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"home","sandboxer","keepassxc",".DirIcon"),
    terminal = false,
    startupnotify = false,
    categories="Utility;Security;Qt;"
  },
}

keepassxc_install_appimage={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/keepassxc && img=`find ./installs -name \"KeePassXC*.AppImage\"|sort|tail -n1` && echo \"installing $img\" && cp \"$img\" /tmp/keepass && chmod 755 /tmp/keepass && 1>/dev/null /tmp/keepass --appimage-extract && mv $HOME/squashfs-root $HOME/keepassxc && rm /tmp/keepass"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

keepassxc_install=keepassxc_install_appimage
