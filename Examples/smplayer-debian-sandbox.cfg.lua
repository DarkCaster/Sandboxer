-- example config for smplayer sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- opengl acceleration should work with opensurce mesa drivers, tested on Intel HD graphics.
-- for proprietary NVIDIA and AMD drivers it may be neccesary to forward it's libgl (and x11 drivers) from host system to sandbox:
-- you can write mount rules for this (see mounts section), or simply copy all files neccesary into external debian chroot

-- redefine some parameters
tunables.datadir=loader.path.combine(loader.workdir,"userdata-mpv")
defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"dbus")
loader.table.remove_value(sandbox.features,"gvfs_fix")

-- remove some mounts
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- add host mounts, readonly
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind","/mnt/data","/mnt/data"})
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind","/mnt/nas","/mnt/nas"})
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind","/media","/media"})

-- add bwrap unshare-net option to cut off sandbox from network
table.insert(sandbox.bwrap,defaults.bwrap.unshare_net)

smplayer_log={
  exec="/usr/bin/smplayer",
  path="/home/sandboxer",
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"smplayer_dbg.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"smplayer_dbg.out.log"),
}

smplayer={
  exec="/usr/bin/smplayer",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "SMPlayer (in sandbox)",
    comment = "SMPlayer, sandbox uid "..config.sandbox_uid,
    field_code="%U",
    icon = loader.path.combine(tunables.chrootdir,"/usr/share/icons/hicolor/256x256/apps","smplayer.png"),
    mimetype = "audio/ac3;audio/mp4;audio/mpeg;audio/vnd.rn-realaudio;audio/vorbis;audio/x-adpcm;audio/x-matroska;audio/x-mp2;audio/x-mp3;audio/x-ms-wma;audio/x-vorbis;audio/x-wav;audio/mpegurl;audio/x-mpegurl;audio/x-pn-realaudio;audio/x-scpls;audio/aac;audio/flac;audio/ogg;video/avi;video/mp4;video/flv;video/mpeg;video/quicktime;video/vnd.rn-realvideo;video/x-matroska;video/x-ms-asf;video/x-msvideo;video/x-ms-wmv;video/x-ogm;video/x-theora;video/webm;",
    terminal = false,
    startupnotify = false,
    categories="Qt;AudioVideo;Video;Player;"
  },
}

svp_manager={
  exec="/home/sandboxer/SVP4/SVPManager",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "SVP 4 Linux (in sandbox)",
    comment = "SVP 4 Linux, sandbox uid "..config.sandbox_uid,
    field_code="%f",
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/SVP4","svp-manager4-128.png"),
    mimetype = "video/x-msvideo;video/x-matroska;video/webm;video/mpeg;video/mp4;",
    terminal = false,
    startupnotify = false,
    categories="Multimedia;AudioVideo;Video;Player;"
  },
}

svp_manager_log={
  exec="/home/sandboxer/SVP4/SVPManager",
  path="/home/sandboxer",
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"svp_dbg.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"svp_dbg.out.log"),
}
