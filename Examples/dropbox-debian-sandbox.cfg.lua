-- example config for dropbox sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be used to isolate sanbox from host x11 service.
-- opengl acceleration untested and may not work (especially with xpra mode or when using proprietary video drivers that install it's own libgl).

-- do not forget to install following packages in addition to packages from debian-minimal-setup.sh:
-- libxslt1.1
-- midori (or any other js capable browser that may be started with xdg-open by dropbox in order to perform initial auth)

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-dropbox")
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
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

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- add bwrap unshare_ipc option, remove following 2 lines if dropbox GUI is not displaying properly
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)
table.insert(sandbox.bwrap,defaults.bwrap.unshare_ipc)

desktop_data={
  name = "Dropbox in sandbox",
  comment = "Start dropbox in sandbox with uid "..config.sandbox_uid,
  icon = loader.path.combine(tunables.datadir,"home","sandboxer","dropbox-linux.png"),
  terminal = false,
  startupnotify = false,
  categories="Network;FileTransfer;"
}

dropbox_install={
  exec="/bin/sh",
  path="/home/sandboxer",
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
}

if os_arch == "i386" then
  dropbox_install.args={ "-c", "test ! -d .dropbox-dist && wget -O dropbox-linux.png \"https://www.dropbox.com/s/ijfcdopwi2pbsj9/dropbox-linux.png?raw=1\" && ( wget -O - \"https://www.dropbox.com/download?plat=lnx.x86\" | tar xzf - ) && .dropbox-dist/dropboxd" }
elseif os_arch == "amd64" then
  dropbox_install.args={ "-c", "test ! -d .dropbox-dist && wget -O dropbox-linux.png \"https://www.dropbox.com/s/ijfcdopwi2pbsj9/dropbox-linux.png?raw=1\" && ( wget -O - \"https://www.dropbox.com/download?plat=lnx.x86_64\" | tar xzf - ) && .dropbox-dist/dropboxd" }
end

dropbox={
  exec="/home/sandboxer/.dropbox-dist/dropboxd",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop=desktop_data,
}
