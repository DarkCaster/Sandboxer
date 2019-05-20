-- example config for vscode-ide sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-vscode")
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
table.insert(sandbox.setup.mounts,{prio=99,"bind","/mnt/data","/mnt/data"})
-- table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/tmp"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

vscode={
  exec="/home/sandboxer/VSCode-linux-x64/code",
  path="/home/sandboxer/VSCode-linux-x64",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "VSCode (in sandbox)",
    comment = "VSCode, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/VSCode-linux-x64/resources/app/resources/linux/code.png"),
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;",
  },
}
