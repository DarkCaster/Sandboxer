defaults.chrootdir=loader.path.combine(loader.workdir,"ubuntu_chroot")

-- special tweaks applied to some of "defaults" entries when using "root" username
-- use "root" username for sandbox only if you want to get pseudo-superuser session
-- do not set it for regular sandbox usage
defaults.user="root"

defaults.uid=0

defaults.gid=0

defaults.recalculate()

sandbox={
  features={
    "rootfixups",
  },
  setup={
    static_executor=false,
    commands={
      {'rm -f "etc/resolv.conf"', 'cp "/etc/resolv.conf" "etc/resolv.conf"'},
      defaults.commands.x11,

    },
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
      defaults.env.set_xdg_runtime,
      defaults.env.set_x11,
      defaults.env.set_home, --equialent to:
      --[[
      {"PATH","/usr/sbin:/sbin:/usr/bin:/bin:/usr/bin/X11"},
      {"HOME","/root"},
      {"USER",defaults.user},
      {"LOGNAME",defaults.user},]]--
    }
  },
  bwrap={
    defaults.bwrap.unshare_user,
    defaults.bwrap.unshare_ipc,
    defaults.bwrap.unshare_pid,
    defaults.bwrap.unshare_uts,
    defaults.bwrap.uid,
    defaults.bwrap.gid,
    defaults.bwrap.proc_mount,
    defaults.bwrap.dev_mount,
    defaults.bwrap.xdg_runtime_dir,
    defaults.bwrap.bin_rw_mount,
    defaults.bwrap.usr_rw_mount,
    defaults.bwrap.lib_rw_mount,
    defaults.bwrap.lib64_rw_mount,
    defaults.bwrap.sys_mount, -- optional for root usage, may leak some system info when installing\configuring packages
    defaults.bwrap.x11_mount, -- optional for root usage, may be used to run synaptic
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"etc"),"/etc"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"boot"),"/boot"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"root"),"/root"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"run"),"/run"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"sbin"),"/sbin"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"srv"),"/srv"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"opt"),"/opt"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"tmp"),"/tmp"},
    {prio=10,"bind",loader.path.combine(defaults.chrootdir,"var"),"/var"},
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
