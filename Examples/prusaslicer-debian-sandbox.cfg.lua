-- example config for prusaslicer sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- if using nvidia GPU, you also need to install same proprietery nvidia driver version into sandbox,
-- also you may need to install libc6-dev and libglvnd-dev

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-prusaslicer")
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
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"input"),"/home/sandboxer/input"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"output"),"/home/sandboxer/output"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

prusaslicer={
  exec="/home/sandboxer/prusaslicer/AppRun",
  path="/home/sandboxer/prusaslicer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  env_set={ -- fix for https://stackoverflow.com/questions/10396141/strange-unicodeencodeerror-using-os-path-exists
    {"LANG","en_US.UTF-8"},
    {"LC_ALL","en_US.UTF-8"},
  },
  desktop={
    name = "Prusaslicer (in sandbox)",
    comment = "Prusaslicer, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/prusaslicer/PrusaSlicer.png"),
    terminal = false,
    startupnotify = false,
    categories="Graphics;",
  },
}

prusaslicer_install_appimage={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/prusaslicer && imgarc=`find $HOME/installs -name \"PrusaSlicer-*-x64-*.AppImage\"|sort -V|tail -n1` && chmod 755 $imgarc && $imgarc --appimage-extract && mv squashfs-root $HOME/prusaslicer"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}
