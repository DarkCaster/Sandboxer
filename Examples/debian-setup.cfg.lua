-- this is an example config for sandbox that use external debian rootfs as base.

-- this example config is compatible with external root-fs archives that was downloaded and extracted by running:
-- download-ubuntu-*.sh - download selected ubuntu x86_64 distribution (currently supported 12.04, 14.04, 16.04 and 16.10)
-- download-debian-jessie-chroot.sh - download debian 8 (jessie) x86_64 rootfs from docker image repository
-- (debian sid distribution is using different root-fs directory layout - it will be NOT COMPATIBLE with this example config file)

-- THIS CONFIG WILL CREATE SANDBOXED ENV THAT SHOULD BE USED ONLY TO PERFORM SETUP PROCEDURES, LIKE INSTALLING PACKAGES OR EDITING /etc/* config files.
-- all root-subdirectories from external rootfs (debian_chroot directory) will be mounted read-write.
-- also pseudo "root" shell will be launched inside sandbox, thay you may use to install extra packages, edit config files and perform stuff like that.
-- most of integration options that provide sandbox to use some of the host features is unavailable inside this sandbox.
-- (x11host feature is the only one that is enabled by default, so you may run GUI programs, but it is strongly recommended to disable it)

-- it is strongly discouraged to use this config to run normal applications inside sandbox. you should use it only for setup purposes of external chroot.

-- chroot directory name, relative to this config file directory
tunables.chrootdir=loader.path.combine(loader.workdir,"debian_chroot")

-- detect debian\ubuntu os version
dofile(loader.path.combine(loader.workdir,"debian-version-probe.lua.in"))

-- special tweaks applied to some of "defaults" entries when using "root" username
-- use "root" username for sandbox only if you want to get pseudo-superuser session
-- do not set it for regular sandbox usage
tunables.user="root"
tunables.uid=0
tunables.gid=0

-- DO NOT FORGET TO LAUNCH THIS IF YOU SET ANY "tubables.*" VARIABLE ABOVE!
defaults.recalculate()

sandbox={
  features={
    "rootfixups", -- add some "fixups" to sandboxed env, that will be used to setup pseudo-root shell later. do not remove!
    "x11host", -- to run synaptic, for example, if you need it. you may safely remove unsecure x11 integration from this temporary "setup" config if you need.
  },
  setup={
    -- set executor utility build, precompiled executor binaries for various platforms may be downloaded by external script (TODO)
    -- it will be set back to "default" executor binary, if missing
    executor_build=os_id.."-"..os_version.."-"..os_arch,
    executor_build_alt=os_id.."-"..os_arch,
    --executor_build="default",

    commands={
      --disable automatic services startup on package installing
      --(or else dpkg configure stage will fail, because there is no running init daemon inside sandbox)
      {'[[ ! -x usr/sbin/policy-rc.d ]] && echo "exit 101" > "usr/sbin/policy-rc.d" && chmod 755 "usr/sbin/policy-rc.d"; true'},
      -- create empty /etc/machine-id file
      {'[[ ! -f "etc/machine-id" ]] && touch "etc/machine-id"; true'},
      {'mkdir -p "etc/pulse"'}, -- we need pulse directory for pulse feature to work if it is not already installed in sandbox by using debian-setup.cfg.lua
      {'touch "etc/resolv.conf"'}, -- create empty resolv.conf at chroot directory, if missing.
      defaults.commands.resolvconf, -- create resolv.conf at dynamic etc directory
    },
    -- only pass some whitelisted env-variables from host to sandboxed env
    env_whitelist={
      "LANG",
      "LC_ALL",
    },
    -- also define some essential env variables for sandboxed env
    env_set={
      {"PATH","/usr/sbin:/sbin:/usr/bin:/bin:/usr/bin/X11"},
      defaults.env.set_xdg_runtime,
      defaults.env.set_home, --equialent to:
      --[[{"HOME","/root"},
      {"USER",tunables.user},
      {"LOGNAME",tunables.user},]]--
    },
    mounts={
      defaults.mounts.proc_mount,
      defaults.mounts.dev_mount,
      defaults.mounts.xdg_runtime_dir,
      defaults.mounts.usr_rw_mount,
      defaults.mounts.resolvconf_mount, -- mount resolv.conf from dynamic etc directory
      -- defaults.mounts.sys_mount, -- optional for root usage, may leak some system info when installing\configuring packages. anyway, it will be mounted readonly.
      -- in normal sandboxes, following directories constructed dynamically (see example.cfg.lua), or not needed at all, but for external chroot case we must explicitly define mounts for it
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"etc"),"/etc"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"boot"),"/boot"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"root"),"/root"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"run"),"/run"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"srv"),"/srv"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"opt"),"/opt"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"tmp"),"/tmp"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"var"),"/var"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"home"),"/home"},
    }
  },
  bwrap={
    defaults.bwrap.unshare_user,
    defaults.bwrap.unshare_ipc,
    defaults.bwrap.unshare_pid,
    defaults.bwrap.unshare_uts,
    defaults.bwrap.uid,
    defaults.bwrap.gid,
  }
}

-- add remaining mounts, depending on detected debian version
if fs_layout=="merged" then
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/bin","bin"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib","lib"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib32","lib32"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/lib64","lib64"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/libx32","libx32"})
  table.insert(sandbox.setup.mounts, {prio=15,"symlink","usr/sbin","sbin"})
else
  table.insert(sandbox.setup.mounts, defaults.mounts.bin_rw_mount)
  table.insert(sandbox.setup.mounts, defaults.mounts.lib_rw_mount)
  if os_arch=="amd64" then
    table.insert(sandbox.setup.mounts, defaults.mounts.lib64_rw_mount)
  end
  table.insert(sandbox.setup.mounts, defaults.mounts.sbin_rw_mount)
end

-- start bash shell with fakeroot utility.
-- by default, it will use bundled fakeroot utilty - it should be compatible with any recent debian or ubuntu distro.
-- but it will search and use fakeroot utilty precompiled for particular distro, if present.
-- (this fakeroot builds maybe downloaded by running sandboxer-download-extra.sh script)
-- this profile should be used to perform package management inside sandbox: apt-get, dpkg should work.
-- but, still there may be some errors, because virtual "root" env running inside regular user sandbox has some very tight restrictions,
-- that may be not overriden even by using fakeroot utility. so, do not expect that every program that require real root privs will work.
fakeroot_shell={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/",
  args={false,os_id..os_version..os_arch,os_id..os_arch,"--","/bin/bash","--login"},
  env_set={ {"TERM",os.getenv("TERM")} },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
  term_on_interrupt=true,
}

fakeroot_shell_db={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/",
  args={true,os_id..os_version..os_arch,os_id..os_arch,"--","/bin/bash","--login"},
  env_set={ {"TERM",os.getenv("TERM")} },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
  term_on_interrupt=true,
}

function concat_table(t1,t2)
  for _,v in ipairs(t2) do
    table.insert(t1, v)
  end
  return t1
end

-- invocation example: sandboxer debian-setup.cfg.lua fakeroot_exec echo ok
-- command execution is performed by fakeroot script, so shell syntax and relative paths allowed
fakeroot_exec={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/root",
  args=concat_table({false,os_id..os_version..os_arch,os_id..os_arch,"--"},loader.args),
  env_set={ {"TERM",os.getenv("TERM")} },
  term_signal=defaults.signals.SIGTERM,
  term_orphans=true,
  attach=true,
  pty=false,
}

fakeroot_exec_db={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/root",
  args=concat_table({true,os_id..os_version..os_arch,os_id..os_arch,"--"},loader.args),
  env_set={ {"TERM",os.getenv("TERM")} },
  term_signal=defaults.signals.SIGTERM,
  term_orphans=true,
  attach=true,
  pty=false,
}
