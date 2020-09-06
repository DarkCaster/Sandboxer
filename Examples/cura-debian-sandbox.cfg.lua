-- example config for ultimaker cura sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- if using nvidia GPU, you also need to install same proprietery nvidia driver version into sandbox,
-- also you need to install libc6-dev and libglvnd-dev (https://community.ultimaker.com/topic/17302-i-keep-getting-segfaults-when-running-cura)

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-cura")
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

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

cura={
  exec="/home/sandboxer/Cura/AppRun",
  path="/home/sandboxer/Cura",
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
    name = "Ultimaker Cura (in sandbox)",
    comment = "Ultimaker Cura, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/Cura/cura-icon.png"),
    terminal = false,
    startupnotify = false,
    categories="Graphics;",
  },
}

cura_install_old_appimage={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","img=`find \"$HOME/installs\" -name \"Cura-*.AppImage\"|sort -V|tail -n1` && echo \"installing $img\" && rm -rf $HOME/Cura && mkdir $HOME/Cura && cd $HOME/Cura && bsdtar xvfp \"$img\""},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

cura_install_appimage={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","img=`find \"$HOME/installs\" -name \"Cura-*.AppImage\"|sort -V|tail -n1` && echo \"installing $img\" && rm -rf $HOME/Cura && mkdir $HOME/Cura && cd $HOME/Cura && bsdtar xvfp \"$img\""},
  args={"-c","rm -rf $HOME/Cura && img=`find ./installs -name \"Ultimaker_Cura-*.AppImage\"|sort -V|tail -n1` && chmod 755 $img && $img --appimage-extract && mv $HOME/squashfs-root $HOME/Cura"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}
