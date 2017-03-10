tunables.chrootdir=loader.path.combine(loader.workdir,"ubuntu_chroot")

-- special tweaks applied to some of "defaults" entries when using "root" username
-- use "root" username for sandbox only if you want to get pseudo-superuser session
-- do not set it for regular sandbox usage
tunables.user="root"
tunables.uid=0
tunables.gid=0
tunables.etcdir_name="etc_orig"
-- use different build of x11 util, if you experience problems, for example:
-- tunables.features.x11util_build="ubuntu-12.04"
defaults.recalculate()

sandbox={
  features={
    "rootfixups",
    "x11host", -- to run synaptic, if you need it. you may safely remove unsecure x11 integration from this temporary "setup" config if you need.
  },
  setup={
    executor_build="default",
    --use one of this builds, if you experience problems with default
    --executor_build="ubuntu-12.04",
    --executor_build="ubuntu-16.10",
    commands={
      --disable automatic services startup on package installing
      --(or else dpkg configure stage will fail, becase there is no running init daemon inside sandbox)
      {'[[ ! -x usr/sbin/policy-rc.d ]] && echo "exit 101" > "usr/sbin/policy-rc.d" && chmod 755 "usr/sbin/policy-rc.d"; true'},
      --copy file with dns configuration from host env
      {'rm -f "etc_orig/resolv.conf"', 'cp "/etc/resolv.conf" "etc_orig/resolv.conf"'},
    },
    -- will be ignored if using env_whitelist. it is just for reference here
    env_blacklist={
      defaults.env.blacklist_main,
      defaults.env.blacklist_audio,
      defaults.env.blacklist_desktop,
      defaults.env.blacklist_home,
      defaults.env.blacklist_xdg,
    },
    env_whitelist={
      "LANG",
      "LC_ALL",
    },
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
      defaults.mounts.sys_mount, -- optional for root usage, may leak some system info when installing\configuring packages
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"etc_orig"),"/etc"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"boot"),"/boot"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"root"),"/root"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"run"),"/run"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"sbin"),"/sbin"},
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

-- start bash shell with fakeroot utility built for ubuntu-16.10 (it maybe downloaded by running sandboxer-download-extra.sh script)
-- this profile should be used to perform package management inside sandbox: apt-get, dpkg should work.
-- but, still there may be some errors, because virtual "root" env running inside regular user sandbox has some very tight restrictions,
-- that may be not overriden even by using fakeroot utility. so, do not expect that every program that require real root privs will work.
fakeroot_shell_16_10={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/",
  args={"ubuntu-16.10","/bin/bash","--login"},
  env_set={
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}

fakeroot_shell_12_04={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/",
  args={"ubuntu-12.04","/bin/bash","--login"},
  env_set={
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
}

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
