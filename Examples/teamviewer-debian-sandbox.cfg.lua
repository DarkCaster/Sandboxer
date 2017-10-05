-- example config for teamviewer sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- this config is based on example.cfg.lua, most comments removed.

-- chroot directory name, relative to this config file directory
tunables.chrootdir=loader.path.combine(loader.workdir,"debian_chroot")

-- detect debian\ubuntu os version
dofile(loader.path.combine(loader.workdir,"debian-version-probe.lua.in"))

tunables.etchost_path=loader.path.combine(tunables.chrootdir,"etc")
tunables.features.dbus_search_prefix=tunables.chrootdir
tunables.features.xpra_search_prefix=tunables.chrootdir
tunables.features.gvfs_fix_search_prefix=tunables.chrootdir
tunables.features.pulse_env_alsa_config="skip"
tunables.features.x11util_build=os_id.."-"..os_version.."-"..os_arch

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
      -- other dirs from our external chroot
      defaults.mounts.usr_ro_mount,
      defaults.mounts.host_etc_mount,
      defaults.mounts.passwd_mount,
      defaults.mounts.machineid_mount,
      defaults.mounts.resolvconf_mount,
      -- optional mounts, may be useful for some programs
      --defaults.mounts.devsnd_mount,
      --defaults.mounts.devdri_mount,
      --defaults.mounts.devinput_mount,
      --defaults.mounts.sys_mount,
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

-- add remaining mounts, depending on detected debian version
add_debian_mounts()

-- add sbin mounts
if os_version > os_oldfs_ver then
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/sbin","sbin"})
else
  table.insert(sandbox.setup.mounts, defaults.mounts.sbin_ro_mount)
end

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
