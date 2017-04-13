-- example config for firefox sandbox, which is created dynamycally from host environment.
-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be used to isolate sanbox from host x11 service.
-- opengl acceleration untested and may not work (especially with xpra mode or when using proprietary video drivers that install it's own libgl).
-- this config is based on example.cfg.lua, most comments removed.

sandbox={
  features={
    "dbus",
    "gvfs_fix",
    "pulse",
    --"x11host", -- less secure, try this if you do not have xpra software
    "xpra", -- more secure, you must install xpra software suite with server and client functionality.
    "envfix",
  },
  setup={
    commands={
      defaults.commands.etc_min,
      defaults.commands.etc_dbus,
      defaults.commands.etc_x11,
      defaults.commands.etc_udev,
      defaults.commands.passwd,
      defaults.commands.home,
      defaults.commands.home_gui_config,
      defaults.commands.machineid,
      defaults.commands.resolvconf,
      defaults.commands.var_cache,
      defaults.commands.var_tmp,
    },
    env_blacklist={
      defaults.env.blacklist_main,
      defaults.env.blacklist_audio,
      defaults.env.blacklist_desktop,
      defaults.env.blacklist_home,
      defaults.env.blacklist_xdg,
    },
    -- set custom env variables,
    env_set={
      defaults.env.set_home,
      defaults.env.set_xdg_runtime,
    },
    mounts={
      defaults.mounts.system_group,
      defaults.mounts.xdg_runtime_dir,
      defaults.mounts.home_mount,
      defaults.mounts.var_cache_mount,
      defaults.mounts.var_tmp_mount,
      defaults.mounts.etc_ro_mount,
      --defaults.mounts.devsnd_mount, -- for alsa support.
      --defaults.mounts.devdri_mount, -- may be needed when using x11host for opengl acceleration
      --defaults.mounts.sys_mount, -- may be needed when using x11host for opengl acceleration
      defaults.mounts.host_bin_mount,
      defaults.mounts.host_usr_mount,
      defaults.mounts.host_lib_mount,
      defaults.mounts.host_lib64_mount,
    }
  },

  bwrap={
    defaults.bwrap.unshare_user,
    defaults.bwrap.unshare_ipc,
    defaults.bwrap.unshare_pid,
    -- defaults.bwrap.unshare_net,
    defaults.bwrap.unshare_uts,
    -- defaults.bwrap.unshare_cgroup,
    defaults.bwrap.uid,
    defaults.bwrap.gid,
  }
}

shell={
  exec="/bin/bash",
  path="/",
  env_unset={"TERM"},
  env_set={{"TERM",os.getenv("TERM")}},
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}

firefox={
  exec="/usr/bin/firefox",
  path="/home/sandboxer",
  args=loader.args,
  env_unset={"TERM"},
  env_set={{"TERM",os.getenv("TERM")}},
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
}
