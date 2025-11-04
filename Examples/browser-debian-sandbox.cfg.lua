-- example config for browser sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be used to isolate sanbox from host x11 service.
-- opengl acceleration untested and may not work (especially with xpra mode or when using proprietary video drivers that install it's own libgl).

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters from "tunables" table that will affect some values from "defaults" table after running recalculate
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-browser")
  tunables.features.pulse_env_alsa_config="auto"
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount) -- remove line, to enable direct alsa support (alsa-pulse may work without it).
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount) -- remove line, to enable opengl acceleration
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount) -- remove line, to enable opengl acceleration
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount) -- remove line, to enable direct access to input devices (joystics, for example)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount) -- remove line, if you experience problems with pulseaudio
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

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
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer","firefox/browser/chrome/icons/default","default128.png"),
    mimetype = "x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;",
    field_code="%u",
    terminal = false,
    startupnotify = false,
    categories="Network;WebBrowser;GTK;"
  },
}

librewolf={
  exec="/usr/bin/librewolf",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "LibreWolf (in sandbox)",
    comment = "LibreWolf browser, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.chrootdir,"/usr/share/librewolf/browser/chrome/icons/default","default128.png"),
    mimetype = "x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;",
    field_code="%u",
    terminal = false,
    startupnotify = false,
    categories="Network;WebBrowser;GTK;"
  },
}

librewolf_home={
  exec="/home/sandboxer/librewolf/librewolf",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "LibreWolf (in sandbox)",
    comment = "LibreWolf browser, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer","librewolf/browser/chrome/icons/default","default128.png"),
    mimetype = "x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;",
    field_code="%u",
    terminal = false,
    startupnotify = false,
    categories="Network;WebBrowser;GTK;"
  },
}

librewolf_home_log={
  exec="/home/sandboxer/librewolf/librewolf",
  path="/home/sandboxer",
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"librewolf.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"librewolf.out.log"),
}

