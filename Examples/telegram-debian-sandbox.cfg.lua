-- example config for telegram sandbox, which is created on top of external debian\ubuntu chroot, prepared by debian-setup.cfg.lua
-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be optionally used to isolate sanbox from host x11 service.

-- NOTE: tested with ubuntu 18.04 based sandbox, use download-ubuntu-chroot.sh script to deploy this chroot
-- NOTE: you may need to install a full pulseaudio package into ubuntu sandbox, in order voice calls to work!

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-telegram")
  -- NOTE: following option may help if you experience voice calls problems, or sound setup problems. Try to install full pulseaudio package inside sandbox first!
  -- tunables.features.pulse_env_alsa_config="auto"
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
  "x11host", -- less secure, try this if you do not have xpra software
  --"xpra", -- more secure, you must install xpra software suite with server and client functionality.
  "envfix",
}

-- remove some mounts from base config
-- NOTE: following line may need to be removed if you want to select non default sound device
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)

-- NOTE: telegram does not need following mounts. you can try to remove some of the following lines in case of problems
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- needed for resolvconf feature
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- add bwrap unshare_ipc option, remove following 2 lines if you are using x11host feature and telegram GUI is not displaying properly
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)
table.insert(sandbox.bwrap,defaults.bwrap.unshare_ipc)

-- sandbox.setup.cleanup_on_exit=false, -- enable for debug purposes

telegram_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e\
  rm -rf Telegram \
  xz -c -d `find $HOME -maxdepth 1 -type f -name *.tar.xz | sort | head -n1` | tar xvf -\
  ./Telegram/Telegram\
  "},
  attach=true,
}

telegram={
  exec="/home/sandboxer/Telegram/Telegram",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  desktop={
    name = "Telegram (in sandbox)",
    generic_name = "IM application",
    comment = "Telegram, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer",".local/share/icons","telegram.png"),
    field_code="-- %u",
    terminal = false,
    mimetype = "x-scheme-handler/tg;",
    startupnotify = false,
    categories="Network;Application;"
  },
}
