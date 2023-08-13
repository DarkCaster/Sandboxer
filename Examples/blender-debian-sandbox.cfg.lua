-- example config for blender sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-blender")
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"pulse")

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

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

blender={
  exec="/home/sandboxer/blender/blender-launcher",
  path="/home/sandboxer/blender",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop={
    name = "Blender (in sandbox)",
    comment = "Blender, sandbox uid "..config.sandbox_uid,
    icon = "blender",
    terminal = false,
    startupnotify = false,
    categories="Graphics;",
  },
}

blender_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/blender && img=`find ./installs -name \"blender-*-linux-x64.tar.xz\"|sort -V|tail -n1` && echo \"extracting $img\" && cp \"$img\" /tmp/blender.tar.xz && cd /tmp && tar xf /tmp/blender.tar.xz && mv blender-*-linux-* $HOME/blender"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}
