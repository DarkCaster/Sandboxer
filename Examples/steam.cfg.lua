-- this is an example config that allows to run steam client in sandbox.
-- using external debian chroot (debian jessie), use download-debian-jessie-chroot.sh to download and prepare rootfs archive.
-- see steam-howto.txt for info about other preparations needed to install and run steam inside sandbox.

-- there may be some problems with 3d acceleration when using hardware that requires to install external driver and its own version of libGL
-- for now this config is tested with Intel IGP that works with stock driers and libGL library.

tunables.chrootdir=loader.path.combine(loader.workdir,"debian_chroot")
tunables.datadir=loader.path.combine(loader.workdir,"userdata-steam")
tunables.etchost_path=loader.path.combine(tunables.chrootdir,"etc")
tunables.features.dbus_search_prefix=tunables.chrootdir
tunables.features.gvfs_fix_search_prefix=tunables.chrootdir
tunables.features.pulse_env_alsa_config="skip"
-- detect os version
function read_os_version()
  local lines = {}
  local os_id="debian"
  local os_version=0
  for line in io.lines(loader.path.combine(tunables.chrootdir,"etc","os-release")) do
    lines[#lines + 1] = line
  end
  for _,line_val in pairs(lines) do
    if string.match(line_val,'VERSION_ID="%d+%.*%d*"') ~= nil then
      os_version=tonumber(string.match(line_val,'%d+%.*%d*'))
    elseif string.match(line_val,'ID=%w+') ~= nil then
      _,os_id=string.match(line_val,'(ID=)(%w+)')
    end
  end
  return os_id, os_version
end
os_id,os_version=read_os_version()
assert(type(os_id)=="string", "failed to parse os id from etc/os_release file")
assert(type(os_version)=="number", "failed to parse os version from etc/os_release file")
-- detect debian arch (arch label file created by debian download script)
function read_os_arch()
  local arch_label_file = io.open(loader.path.combine(tunables.chrootdir,"arch-label"), "r")
  local arch_label="amd64"
  if arch_label_file then
    arch_label = arch_label_file:read()
    arch_label_file:close()
  end
  return arch_label
end
os_arch=read_os_arch()
if os_id=="debian" then
  os_oldfs_ver=8
elseif os_id=="ubuntu" then
  os_oldfs_ver=999 -- for now, cloudimg for 17.04 use old fs layout without symlinks for /bin /sbin /lib, etc ...
  -- os_oldfs_ver=17.04001
else
  os_oldfs_ver=999
end
-- set x11 test utility build
tunables.features.x11util_build=os_id.."-"..os_version.."-"..os_arch
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

-- add remaining mounts, depending on detected debian version
if os_version > os_oldfs_ver then
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/bin","bin"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib","lib"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib32","lib32"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib64","lib64"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/libx32","libx32"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/sbin","sbin"})
else
  table.insert(sandbox.setup.mounts, defaults.mounts.bin_ro_mount)
  table.insert(sandbox.setup.mounts, defaults.mounts.lib_ro_mount)
  table.insert(sandbox.setup.mounts, defaults.mounts.lib64_ro_mount)
  table.insert(sandbox.setup.mounts, defaults.mounts.sbin_ro_mount)
end

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
  desktop={
    name = "Shell for steam sandbox",
    comment = "shell for sandbox uid "..config.sandbox_uid,
    icon = "terminal",
    terminal = true,
    startupnotify = false,
  },
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
