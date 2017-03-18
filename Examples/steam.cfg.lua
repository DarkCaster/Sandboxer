-- this is an example of config for runnint steam client in sandbox.
-- using external debian chroot (debian jessie), use download-debian-jessie-chroot.sh to download and prepare rootfs archive.
-- see steam-howto.txt for info about other preparations needed to install and run steam inside sandbox.

-- there may be some problems with 3d acceleration when using hardware that requires to install external driver and its own version of libGL
-- for now this config is tested with Intel IGP that works with stock driers and libGL library.

tunables.chrootdir=loader.path.combine(loader.workdir,"debian_chroot")
tunables.datadir=loader.path.combine(loader.workdir,"userdata-steam")
tunables.etchost_path=loader.path.combine(tunables.chrootdir,"etc")
tunables.features.dbus_search_prefix=tunables.chrootdir
tunables.features.gvfs_fix_search_prefix=tunables.chrootdir
-- use different build of x11 util, if you experience problems, for example:
-- tunables.features.x11util_build="debian-8"
tunables.features.pulse_env_alsa_config="skip"
defaults.recalculate()

sandbox={
  features={
    "dbus",
    "gvfs_fix",
    "pulse",
    "x11host",
    "envfix",
  },
  setup={
    executor_build="default",
    --executor_build="debian-8",
    commands={
      defaults.commands.resolvconf,
      defaults.commands.machineid_static,
      defaults.commands.passwd,
      defaults.commands.home,
      defaults.commands.home_gui_config,
      defaults.commands.var_cache,
      defaults.commands.var_tmp,
      {'mkdir -p "${cfg[tunables.auto.user_path]}/libs/i386"'},
      {'mkdir -p "${cfg[tunables.auto.user_path]}/libs/x86_64"'},
    },
    env_whitelist={
      "LANG",
      "LC_ALL",
    },
    env_set={
      {"PATH","/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"},
      defaults.env.set_xdg_runtime,
      defaults.env.set_home,
    },
    mounts={
      defaults.mounts.system_group, -- includes: proc, dev, empty /run dir, empty /var dir, empty /tmp
      defaults.mounts.xdg_runtime_dir,
      defaults.mounts.home_mount,
      defaults.mounts.var_cache_mount,
      defaults.mounts.var_tmp_mount,
      defaults.mounts.var_lib_mount,
      defaults.mounts.bin_ro_mount,
      defaults.mounts.usr_ro_mount,
      defaults.mounts.lib_ro_mount,
      defaults.mounts.lib64_ro_mount,
      defaults.mounts.sbin_ro_mount,
      defaults.mounts.host_etc_mount,
      defaults.mounts.passwd_mount,
      defaults.mounts.machineid_mount,
      defaults.mounts.resolvconf_mount,
      defaults.mounts.devsnd_mount, -- for alsa. may be needed for some games
      defaults.mounts.devdri_mount, -- needed for mesa and 3d
      defaults.mounts.devinput_mount, -- joystics
      defaults.mounts.sys_mount, -- needed for proper 3d support
      --defaults.mounts.dbus_system_mount, -- enable to allow steam queries to network-manager (this should speedup steam startup, TODO: not tested)
      --defaults.mounts.devshm_mount,
    },
  },

  bwrap={
    defaults.bwrap.unshare_user,
    --defaults.bwrap.unshare_ipc, -- ipc isolation must be disabled to use x11 and mesa hw-acceleration
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
  args={"-l"},
  path="/",
  env_set={
    {"STEAM_RUNTIME","0"},
    {"LD_LIBRARY_PATH","/home/sandboxer/libs/i386:/home/sandboxer/libs/x86_64"},
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}

steam={
  exec="/usr/bin/steam",
  path="/home/sandboxer",
  env_set={
    {"STEAM_RUNTIME","0"},
    {"LD_LIBRARY_PATH","/home/sandboxer/libs/i386:/home/sandboxer/libs/x86_64"},
  },
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"steam.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"steam.out.log"),
  desktop={
    name = "Sandboxed Steam Client",
    comment = "Steam for sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.chrootdir,"usr/share/pixmaps/steam.png"),
    terminal = false,
    startupnotify = false,
  },
}
