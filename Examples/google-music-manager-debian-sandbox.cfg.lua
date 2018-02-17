-- example config for google music manager sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be used to isolate sanbox from host x11 service.
-- opengl acceleration untested and may not work (especially with xpra mode or when using proprietary video drivers that install it's own libgl).

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-google-mm")
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- redefine sandbox.features table
sandbox.features={
  "dbus",
  "gvfs_fix",
  "pulse",
  --"x11host",
  "xpra",
  "envfix",
}

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount) -- remove line, to enable direct alsa support (alsa-pulse may work without it).
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount) -- remove line, to enable opengl acceleration
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount) -- remove line, to enable opengl acceleration
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount) -- remove line, to enable direct access to input devices (joystics, for example)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount) -- remove line, if you experience problems with pulseaudio
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- add bwrap unshare_ipc option, remove following 2 lines if dropbox GUI is not displaying properly
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)
table.insert(sandbox.bwrap,defaults.bwrap.unshare_ipc)

gmm_log={
  exec="/home/sandboxer/musicmanager/google-musicmanager",
  path="/home/sandboxer/musicmanager",
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"google-musicmanager.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"google-musicmanager.out.log"),
}

gmm={
  exec="/home/sandboxer/musicmanager/google-musicmanager",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Google Music Manager (in sandbox)",
    comment = "Google Music Manager, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"home","sandboxer","musicmanager","product_logo_128.png"),
    terminal = false,
    startupnotify = false,
    categories="AudioVideo;Audio;Network;"
  },
}
