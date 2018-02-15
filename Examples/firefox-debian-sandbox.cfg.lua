-- example config for firefox sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be used to isolate sanbox from host x11 service.
-- opengl acceleration untested and may not work (especially with xpra mode or when using proprietary video drivers that install it's own libgl).

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-firefox")
  tunables.features.pulse_env_alsa_config="auto"
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some mounts
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

firefox_log={
  exec="/usr/bin/firefox",
  path="/home/sandboxer",
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"firefox_dbg.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"firefox_dbg.out.log"),
}

firefox={
  exec="/usr/bin/firefox",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Firefox (in sandbox)",
    comment = "Firefox browser, sandbox uid "..config.sandbox_uid,
    icon = "firefox",
    mimetype = "x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;",
    field_code="%u",
    terminal = false,
    startupnotify = false,
    categories="Network;WebBrowser;GTK;"
  },
}

firefox_home_log={
  exec="/home/sandboxer/firefox/firefox",
  path="/home/sandboxer",
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"firefox_dbg.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"firefox_dbg.out.log"),
}

firefox_home={
  exec="/home/sandboxer/firefox/firefox",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Firefox (in sandbox)",
    comment = "Firefox browser, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"home","sandboxer","firefox","browser","icons","mozicon128.png"),
    mimetype = "x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;",
    field_code="%u",
    terminal = false,
    startupnotify = false,
    categories="Network;WebBrowser;GTK;"
  },
}
