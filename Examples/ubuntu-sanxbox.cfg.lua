defaults.chrootdir=loader.path.combine(loader.workdir,"ubuntu_chroot")
defaults.etcdir_name="etc_sandbox"
defaults.etchost_path=loader.path.combine(defaults.chrootdir,"etc_orig")
defaults.features.gvfs_fix_search_prefix=defaults.chrootdir
-- use different build of x11 util, if you experience problems, for example:
-- defaults.features.x11util_build="ubuntu-12.04"
defaults.recalculate()

sandbox={
  -- sandbox features and host-integration stuff that require some complex or dynamic preparations.
  -- features are enabled in order of appearance, feature name may contain only lowercase letters, numbers and underscores.
  features={
    "dbus",
    "gvfs_fix",
    "pulse",
    "x11host",
    "envfix",
  },
  setup={
    executor_build="default",
    --use one of this builds, if you experience problems with default
    --executor_build="ubuntu-12.04",
    --executor_build="ubuntu-16.10",
    commands={
      -- update resolv.conf in chroot/etc directory.
      {'rm -f "etc_orig/resolv.conf"', 'cp "/etc/resolv.conf" "etc_orig/resolv.conf"'},

      -- usually, when creating sandbox from host env, it is recommended to dynamically construct etc dir for sandbox.
      -- construction is needed to filter some sensitive system configuration info
      -- (and also prevent host /etc from possible damage, but, anyway it should not be possible without real root privs).
      -- when we using separate chroot as base, there are several possible options to construct etc directory for sandbox:

      --1. copy only minimal config from ubuntu chroot that was setup at ubuntu-setup.cfg.lua
      --[[defaults.commands.etc_min,
      defaults.commands.etc_dbus,
      defaults.commands.etc_x11,
      defaults.commands.etc_udev,]]--

      --2. or, instead, copy full config
      --defaults.commands.etc_full, -- copy full /etc to to defaults.chrootdir, may remove existing

      --3. or, just mount chroot config later with defaults.mounts.host_etc_mount and defaults.mounts.passwd_mount
      --but we need pulse directory for pulse feature to work if it is not already installed in sandbox by using ubuntu-setup.cfg.lua
      {'mkdir -p "'..defaults.etchost_path..'/pulse"'},

      -- generate default /etc/passwd and /etc/group files with "sandbox" user (mapped to current uid)
      -- will be placed to "etc_sandbox" directory and will not overwrite files inside "etc_orig" directory managed by ubuntu-setup.cfg.lua
      defaults.commands.passwd,

      -- various stuff for userdata
      defaults.commands.home,
      defaults.commands.home_gui_config,
      defaults.commands.var_cache,
      defaults.commands.var_tmp,
    },
    -- when we use external chroot as base, we should construct our own env from scratch, rather than use filtered env from host
    -- so, allow to transfer only some selected variables
    env_whitelist={
      "LANG",
      "LC_ALL",
    },
    -- construct some essential env variables
    env_set={
      {"PATH","/usr/bin:/bin:/usr/bin/X11"},
      defaults.env.set_xdg_runtime,
      defaults.env.set_home,
    },

    mounts={
      defaults.mounts.system_group, -- includes: proc, dev, constructed run, constructed var, constructed tmp
      defaults.mounts.xdg_runtime_dir,
      defaults.mounts.home_mount,
      defaults.mounts.var_cache_mount,
      defaults.mounts.var_tmp_mount,

      -- other dirs from our external chroot
      defaults.mounts.bin_ro_mount,
      defaults.mounts.usr_ro_mount,
      defaults.mounts.lib_ro_mount,
      defaults.mounts.lib64_ro_mount,
      {prio=10,"ro-bind",loader.path.combine(defaults.chrootdir,"sbin"),"/sbin"},
      {prio=10,"ro-bind",loader.path.combine(defaults.chrootdir,"srv"),"/srv"},
      {prio=10,"ro-bind",loader.path.combine(defaults.chrootdir,"opt"),"/opt"},

      -- if we are using option 3 when constructing etc for our sandbox.
      -- see "commands" section above for more details.
      -- disable following two mounts if using another method of etc generation
      defaults.mounts.host_etc_mount,
      defaults.mounts.passwd_mount,

      -- optional mounts, may be useful for some programs
      defaults.mounts.devsnd_mount,
      defaults.mounts.devdri_mount,
      defaults.mounts.devinput_mount,
      defaults.mounts.sys_mount,
      defaults.mounts.devshm_mount,
    },
  },

  bwrap={
    defaults.bwrap.unshare_user,
    -- defaults.bwrap.unshare_ipc,
    defaults.bwrap.unshare_pid,
    -- defaults.bwrap.unshare_net,
    defaults.bwrap.unshare_uts,
    -- defaults.bwrap.unshare_cgroup,

    -- optional, if you do not touch defaults.uid and defaults.gid tunable parameters
    defaults.bwrap.uid,
    defaults.bwrap.gid,
  }
}

shell={
  exec="/bin/bash",
  args={"-l"},
  path="/",
  env_set={
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}
