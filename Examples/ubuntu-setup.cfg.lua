-- this is an example config for sandbox that use external ubuntu rootfs as base.

-- this example config is compatible with external root-fs archives that was downloaded and extracted by running:
-- download-ubuntu-*.sh - download selected ubuntu x86_64 distribution (currently supported 12.04, 14.04, 16.04 and 16.10)
-- download-debian-jessie-chroot.sh - download debian 8 (jessie) x86_64 rootfs from docker image repository
-- (debian sid distribution is using different root-fs directory layout - it will be NOT COMPATIBLE with this example config file)

-- THIS CONFIG WILL CREATE SANDBOXED ENV THAT SHOULD BE USED ONLY TO PERFORM SETUP PROCEDURES, LIKE INSTALLING PACKAGES OR EDITING /etc/* config files.
-- all root-subdirectories from external rootfs (ubuntu_chroot directory) will be mounted read-write.
-- also pseudo "root" shell will be launched inside sandbox, thay you may use to install extra packages, edit config files and perform stuff like that.
-- most of integration options that provide sandbox to use some of the host features is unavailable inside this sandbox.
-- (x11host feature is the only one that is enabled by default, so you may run GUI programs, but it is strongly recommended to disable it)

-- it is strongly discouraged to use this config to run normal applications inside sandbox. you should use it only for setup purposes of external chroot.

tunables.chrootdir=loader.path.combine(loader.workdir,"ubuntu_chroot")
--tunables.chrootdir=loader.path.combine(loader.workdir,"debian_chroot") -- for debian distribution

-- special tweaks applied to some of "defaults" entries when using "root" username
-- use "root" username for sandbox only if you want to get pseudo-superuser session
-- do not set it for regular sandbox usage
tunables.user="root"
tunables.uid=0
tunables.gid=0
-- use different build of x11 util, if you experience problems, for example:
-- tunables.features.x11util_build="ubuntu-12.04"

-- DO NOT FORGET TO LAUNCH THIS IF YOU SET ANY "tubables.*" VARIABLE ABOVE!
defaults.recalculate()

sandbox={
  features={
    "rootfixups", -- add some "fixups" to sandboxed env, that will be used to setup pseudo-root shell later. do not remove!
    "x11host", -- to run synaptic, for example, if you need it. you may safely remove unsecure x11 integration from this temporary "setup" config if you need.
  },
  setup={
    executor_build="default",
    --use one of this builds, if you experience problems with default
    --executor_build="ubuntu-16.04",
    --executor_build="debian-8",
    commands={
      --disable automatic services startup on package installing
      --(or else dpkg configure stage will fail, because there is no running init daemon inside sandbox)
      {'[[ ! -x usr/sbin/policy-rc.d ]] && echo "exit 101" > "usr/sbin/policy-rc.d" && chmod 755 "usr/sbin/policy-rc.d"; true'},
      --copy file with dns configuration from host env
      {'rm -f "etc/resolv.conf"', 'cp "/etc/resolv.conf" "etc/resolv.conf"'},
      {'[[ ! -f "etc/machine-id" ]] && touch "etc/machine-id"; true'},
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
      defaults.mounts.bin_rw_mount,
      defaults.mounts.usr_rw_mount,
      defaults.mounts.lib_rw_mount,
      defaults.mounts.lib64_rw_mount,
      defaults.mounts.sbin_rw_mount,
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

-- start bash shell with fakeroot utility built for ubuntu-16.04. it compatible with ubuntu 12.04,14.04 and 16.04
-- (this fakeroot build maybe downloaded by running sandboxer-download-extra.sh script)
-- this profile should be used to perform package management inside sandbox: apt-get, dpkg should work.
-- but, still there may be some errors, because virtual "root" env running inside regular user sandbox has some very tight restrictions,
-- that may be not overriden even by using fakeroot utility. so, do not expect that every program that require real root privs will work.
fakeroot_shell={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/",
  args={"ubuntu-16.04","/bin/bash","--login"},
  --args={"debian-8","/bin/bash","--login"},
  env_set={
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}

-- do not use this exec profile, use fakeroot_shell instead.
-- you should use this only for test and debug purposes
-- (if you have some problems starting fakeroot_shell exec profile)
-- apt-get, dpkg will not work with this profile.
shell={
  exec="/bin/bash",
  path="/",
  env_set={
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}
