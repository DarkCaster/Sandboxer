-- example config for dropbox sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- xpra x11-forwarding software (must be installed on host, v2.0 and up) may be used to isolate sanbox from host x11 service.
-- opengl acceleration untested and may not work (especially with xpra mode or when using proprietary video drivers that install it's own libgl).
-- this config is based on example.cfg.lua, most comments removed.

-- do not forget to install following packages in addition to packages from debian-minimal-setup.sh:
-- libxslt1.1
-- midori (or any other js capable browser that may be started with xdg-open by dropbox in order to perform initial auth)

tunables.chrootdir=loader.path.combine(loader.workdir,"debian_chroot")
dofile(loader.path.combine(loader.workdir,"debian-version-probe.lua.in"))

tunables.datadir=loader.path.combine(loader.workdir,"userdata-dropbox")
tunables.etchost_path=loader.path.combine(tunables.chrootdir,"etc")
tunables.features.dbus_search_prefix=tunables.chrootdir
tunables.features.xpra_search_prefix=tunables.chrootdir
tunables.features.gvfs_fix_search_prefix=tunables.chrootdir
tunables.features.pulse_env_alsa_config="skip"
tunables.features.x11util_build=os_id.."-"..os_version.."-"..os_arch
defaults.recalculate()

sandbox={
  features={
    "dbus",
    "gvfs_fix",
    "pulse",
    "x11host", -- less secure, try this if you do not have xpra software
    --"xpra", -- more secure, you must install xpra software suite with server and client functionality.
    "envfix",
  },
  setup={
    executor_build=os_id.."-"..os_version.."-"..os_arch,
    commands={
      defaults.commands.resolvconf,
      defaults.commands.machineid_static,
      defaults.commands.passwd,
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
      {"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"},
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
      defaults.mounts.usr_ro_mount,
      defaults.mounts.host_etc_mount,
      defaults.mounts.passwd_mount,
      defaults.mounts.machineid_mount,
      defaults.mounts.resolvconf_mount,
      --defaults.mounts.devsnd_mount, -- for alsa support.
      --defaults.mounts.devdri_mount, -- may be needed when using x11host for opengl acceleration
      --defaults.mounts.sys_mount, -- may be needed when using x11host for opengl acceleration
      --defaults.mounts.devinput_mount, -- joystics
      --defaults.mounts.devshm_mount,
    },
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

-- add remaining mounts, depending on detected debian version
if os_version > os_oldfs_ver then
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/bin","bin"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib","lib"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib32","lib32"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib64","lib64"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/libx32","libx32"})
  --table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/sbin","sbin"})
else
  table.insert(sandbox.setup.mounts, defaults.mounts.bin_ro_mount)
  table.insert(sandbox.setup.mounts, defaults.mounts.lib_ro_mount)
  table.insert(sandbox.setup.mounts, defaults.mounts.lib64_ro_mount)
  --table.insert(sandbox.setup.mounts, defaults.mounts.sbin_ro_mount)
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
  desktop={
    name = "Shell for dropbox sandbox",
    comment = "shell for sandbox uid "..config.sandbox_uid,
    icon = "terminal",
    terminal = true,
    startupnotify = false,
  },
}

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
