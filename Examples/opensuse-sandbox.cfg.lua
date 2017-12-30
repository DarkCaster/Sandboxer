-- this is an example config for sandbox that use external opensuse rootfs as base.
-- config based on ubuntu-sandbox.cfg.lua, and will be maintained as small as possible - most notes removed.
-- see ubuntu-sandbox.cfg.lua and example.cfg.lua for more comments and information about config options

-- this example config is compatible with external root-fs archives that was downloaded and extracted by running:
-- download-opensuse-42.2-chroot.sh - download opensuse 42.2 x86_64 distribution from docker repository
-- download-opensuse-tumbleweed-chroot.sh - download opensuse tumbleweed x86_64 distribution from docker repository

-- THIS CONFIG WILL CREATE REGULAR SANDBOXED ENV FROM CHROOT DIRECTORY, THAT WAS PREVIOUSLY SETUP WITH opensuse-setup.cfg.lua.
-- it is strongly recommended to use this config rather than opensuse-setup.cfg.lua to run regular software, most of desktop integration options enabled by default with this config.

tunables.chrootdir=loader.path.combine(loader.workdir,"opensuse_chroot")
dofile(loader.path.combine(loader.workdir,"opensuse-version-probe.lua.in")) -- detect os, version and arch
tunables.etchost_path=loader.path.combine(tunables.chrootdir,"etc")
tunables.features.dbus_search_prefix=tunables.chrootdir
tunables.features.xpra_search_prefix=tunables.chrootdir
tunables.features.gvfs_fix_search_prefix=tunables.chrootdir
tunables.features.x11util_build=os_id.."-"..os_version.."-"..os_arch
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
    executor_build=os_id.."-"..os_version.."-"..os_arch,
    commands={
      defaults.commands.machineid_static,
      defaults.commands.passwd,
      defaults.commands.resolvconf,
      defaults.commands.home,
      defaults.commands.home_gui_config,
      defaults.commands.var_cache,
      defaults.commands.var_tmp,
    },
    env_whitelist={
      "LANG",
      "LC_ALL",
    },
    env_set={
      {"PATH","/usr/local/bin:/usr/bin:/bin:/usr/games:/usr/lib/mit/bin:/usr/lib/mit/sbin"},
      defaults.env.set_xdg_runtime,
      defaults.env.set_home,
    },
    mounts={
      defaults.mounts.system_group,
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
      {prio=10,"ro-bind",loader.path.combine(tunables.chrootdir,"srv"),"/srv"},
      {prio=10,"ro-bind",loader.path.combine(tunables.chrootdir,"opt"),"/opt"},
      defaults.mounts.host_etc_mount,
      defaults.mounts.passwd_mount,
      defaults.mounts.machineid_mount,
      defaults.mounts.resolvconf_mount,
      defaults.mounts.devsnd_mount,
      defaults.mounts.devdri_mount,
      defaults.mounts.devinput_mount,
      defaults.mounts.sys_mount,
    },
  },

  bwrap={
    defaults.bwrap.unshare_user,
    -- defaults.bwrap.unshare_ipc,
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
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}

function trim_args(t1)
  table.remove(t1,1)
  table.remove(t1,1)
  return t1
end

-- invocation example: sandboxer opensuse-sandbox.cfg.lua cmd_exec / /bin/ls -la
-- execution is performed by using execvp call, so you must provide absolute path for target binary
cmd_exec={
  exec=loader.args[2],
  path=loader.args[1],
  args=trim_args(loader.args),
  env_set={
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}
