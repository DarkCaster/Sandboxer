-- example config for skype sandbox, which is created on top of external debian\ubuntu chroot, prepared by debian-setup.cfg.lua
-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be optionally used to isolate sanbox from host x11 service.

-- NOTE: tested with ubuntu 18.04 based sandbox, use download-ubuntu-chroot.sh script to deploy this chroot
-- NOTE: you need to install a full pulseaudio package into ubuntu sandbox, in order voice calls to work!

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-skype")
  -- NOTE: following option may help if you experience voice calls problems, or sound setup problems. Try to install full pulseaudio package inside sandbox first!
  tunables.features.pulse_env_alsa_config="auto"
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- redefine sandbox.features table
sandbox.features={
  "resolvconf",
  "dbus",
  "gvfs_fix",
  "pulse",
  "x11host", -- less secure, try this if you do not have xpra software, or if you want "show desktop" feature in skype to work
  --"xpra", -- more secure, you must install xpra software suite with server and client functionality.
  "envfix",
}

-- remove some mounts from base config
-- NOTE: following line may need to be removed if you want to select non default sound device in skype options
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)

-- NOTE: skype does not need following mounts. you can try to remove some of the following lines in case of problems
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- needed for resolvconf feature
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- add bwrap unshare_ipc option, remove following 2 lines if you are using x11host feature and skype GUI is not displaying properly
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)
--table.insert(sandbox.bwrap,defaults.bwrap.unshare_ipc)

-- sandbox.setup.cleanup_on_exit=false, -- enable for debug purposes

skype_log={
  exec="/usr/share/skypeforlinux/skypeforlinux",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"skype_dbg.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"skype_dbg.out.log"),
}

skype={
  exec="/usr/share/skypeforlinux/skypeforlinux",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Skype (in sandbox)",
    comment = "Skype, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.chrootdir,"usr","share","pixmaps","skypeforlinux.png"),
    field_code="%U",
    terminal = false,
    mimetype = "x-scheme-handler/skype;",
    startupnotify = false,
    categories="Network;Application;"
  },
}

skype_install_deb={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e\
  rm -rf extract && mkdir -p extract\
  dpkg -x `find $HOME -maxdepth 1 -type f -name *.deb | sort | head -n1` extract\
  rm -rf skypeforlinux\
  mv extract/usr/share/skypeforlinux skypeforlinux\
  mv extract/usr/share/icons/hicolor/256x256/apps/skypeforlinux.png .\
  rm -rf extract\
  "},
  attach=true,
}

skype_home={
  exec="/home/sandboxer/skypeforlinux/skypeforlinux",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  desktop={
    name = "Skype (in sandbox)",
    comment = "Skype, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer","skypeforlinux.png"),
    field_code="%U",
    terminal = false,
    mimetype = "x-scheme-handler/skype;",
    startupnotify = false,
    categories="Network;Application;"
  },
}
