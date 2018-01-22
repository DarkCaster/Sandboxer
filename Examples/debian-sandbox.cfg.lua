-- this is an example config for sandbox that use external debian rootfs as base.

-- this example config is compatible with external root-fs archives that was downloaded and extracted by running:
-- download-ubuntu-*.sh - download selected ubuntu x86_64 distribution (currently supported 12.04, 14.04, 16.04 and 16.10)
-- download-debian-jessie-chroot.sh - download debian 8 (jessie) x86_64 rootfs from docker image repository
-- (debian sid distribution is using different root-fs directory layout - it will be NOT COMPATIBLE with this example config file)

-- THIS CONFIG WILL CREATE REGULAR SANDBOXED ENV FROM CHROOT DIRECTORY, THAT WAS PREVIOUSLY SETUP WITH debian-setup.cfg.lua.
-- all root-subdirectories from external rootfs (debian_chroot directory) will be mounted read-only.
-- most changes to root-fs inside sandbox will be discarded on exit, leaving chroot directory totally intact.
-- some user-data, however, will be persistently stored at location defined by "tunables.datadir" parameter (see example.cfg.lua for more details)
-- this data includes /var/tmp directory, /var/cache directory and /home directory

-- it is strongly recommended to use this config rather than debian-setup.cfg.lua to run regular software, most of desktop integration options enabled by default with this config.

-- chroot directory name, relative to this config file directory
tunables.chrootdir=loader.path.combine(loader.workdir,"debian_chroot")

-- detect debian\ubuntu os version
dofile(loader.path.combine(loader.workdir,"debian-version-probe.lua.in"))

tunables.etchost_path=loader.path.combine(tunables.chrootdir,"etc")
tunables.features.dbus_search_prefix=tunables.chrootdir
tunables.features.xpra_search_prefix=tunables.chrootdir
tunables.features.gvfs_fix_search_prefix=tunables.chrootdir

-- set custom alsa config file path, exported as ALSA_CONFIG_PATH. "skip" will disable export this var to sandbox, which is neccecary for stock ubuntu or debian based chroot.
tunables.features.pulse_env_alsa_config="skip"

-- set x11 test utility build
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
    -- set executor utility build, precompiled executor binaries for various platforms may be downloaded by external script (TODO)
    -- it will be set back to "default" executor binary, if missing
    executor_build=os_id.."-"..os_version.."-"..os_arch,
    --executor_build="default",

    commands={
      -- usually, when creating sandbox from host env, it is recommended to dynamically construct etc dir for sandbox.
      -- construction is needed to filter some sensitive system configuration info
      -- (and also prevent host /etc from possible damage, but, anyway it should not be possible without real root privs).
      -- when we using separate chroot as base, there are several possible options to construct etc directory for sandbox:

      --1. copy only minimal config from debian chroot that was setup at debian-setup.cfg.lua
      --[[defaults.commands.etc_min,
      defaults.commands.etc_dbus,
      defaults.commands.etc_x11,
      defaults.commands.etc_udev,
      defaults.commands.machineid_static,]]--

      --2. or, instead, copy full config
      --defaults.commands.etc_full,
      --defaults.commands.machineid_static, -- create machine-id file in dynamic etc directory, generated machine-id rely only to sandbox_uid value

      --3. or, work directly with etc directory of our external chroot, and mount it later with defaults.mounts.host_etc_mount.
      -- this directory is specified by tunables.etchost_path tunable at the top of this config file.
      -- we should also mount dynamically created /etc/passwd and /etc/group config files with defaults.mounts.passwd_mount.
      -- (but we can just overwrite this files inside etc directory of chroot, but it may break debian-setup.cfg.lua startup)
      -- also, we need to perform some minor configuration for our chroot etc dir.
      defaults.commands.machineid_static, -- create machine-id file in dynamic etc directory, generated machine-id rely only to sandbox_uid value

      -- remaining commands, used for any etc management option choosen above.

      -- generate default /etc/passwd and /etc/group files with "sandbox" user (mapped to current uid)
      -- will be placed to dynamic (temporary) etc directory and will not overwrite files inside "etc" directory managed by debian-setup.cfg.lua
      defaults.commands.passwd,
      defaults.commands.resolvconf, -- generate resolvconf and place it to dynamic etc directory
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
      {prio=10,"ro-bind",loader.path.combine(tunables.chrootdir,"srv"),"/srv"},
      {prio=10,"ro-bind",loader.path.combine(tunables.chrootdir,"opt"),"/opt"},

      -- if we are using option 3 when constructing etc for our sandbox.
      -- see "commands" section above for more details.
      -- disable following four mounts if using another method of etc generation
      defaults.mounts.host_etc_mount,
      defaults.mounts.passwd_mount,
      defaults.mounts.machineid_mount,
      defaults.mounts.resolvconf_mount,

      -- optional mounts, may be useful for some programs
      defaults.mounts.devsnd_mount,
      defaults.mounts.devdri_mount,
      defaults.mounts.devinput_mount,
      defaults.mounts.sys_mount, -- needed for mesa and 3d to work. may leak some system info. anyway, it will be mounted readonly if enabled.
      -- defaults.mounts.devshm_mount, - enable posix_shm sharing between host and sandbox. may break old pulseaudio (<9.0), may be needed for some apps to work, weakens security and isolation.
    },
  },

  bwrap={
    defaults.bwrap.unshare_user,
    -- defaults.bwrap.unshare_ipc,
    defaults.bwrap.unshare_pid,
    -- defaults.bwrap.unshare_net,
    defaults.bwrap.unshare_uts,
    -- defaults.bwrap.unshare_cgroup,

    -- optional, if you do not touch tunables.uid and tunables.gid tunable parameters
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

function trim_args(t1)
  table.remove(t1,1)
  table.remove(t1,1)
  return t1
end

-- invocation example: sandboxer debian-sandbox.cfg.lua cmd_exec / /bin/ls -la
-- execution is performed by using execvp call, so you must provide absolute path for target binary
cmd_exec={
  exec=loader.args[2],
  path=loader.args[1],
  args=trim_args(loader.args),
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}
