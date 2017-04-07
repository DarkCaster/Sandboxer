-- this is an example config for sandbox that use external opensuse rootfs as base.
-- config based on ubuntu-setup.cfg.lua, and will be maintained as small as possible.
-- see ubuntu-setup.cfg.lua and example.cfg.lua for more comments and information about config options

-- this example config is compatible with external root-fs archives that was downloaded and extracted by running:
-- download-opensuse-42.2-chroot.sh - download opensuse 42.2 x86_64 distribution from docker repository
-- download-opensuse-tumbleweed-chroot.sh - download opensuse tumbleweed x86_64 distribution from docker repository

-- THIS CONFIG WILL CREATE SANDBOXED ENV THAT SHOULD BE USED ONLY TO PERFORM SETUP PROCEDURES, LIKE INSTALLING PACKAGES OR EDITING /etc/* config files.
-- it is strongly discouraged to use this config to run normal applications inside sandbox. you should use it only for setup purposes of external chroot.

tunables.chrootdir=loader.path.combine(loader.workdir,"opensuse_chroot")
tunables.etchost_path=loader.path.combine(tunables.chrootdir,"etc") -- needed for defaults.commands.machineid_host_etc
tunables.user="root"
tunables.uid=0
tunables.gid=0
-- tunables.features.x11util_build="opensuse-42.2"
defaults.recalculate()

sandbox={
  features={
    "rootfixups",
    "x11host", -- to run yast and handy package manager gui
  },
  setup={
    executor_build="opensuse-42.2",
    commands={
      --remove tty system group. this will fix openpty failures
      {'cat etc/group | grep -vE \'^tty:x:[0-9].*:$\' > etc/group.new','mv etc/group.new etc/group'},
      {'mkdir -p "etc/pulse"'},
      {'touch "etc/resolv.conf"'},
      defaults.commands.resolvconf,
      defaults.commands.machineid_host_etc, -- we need etc/machine-id for yast2. anyway, it will be redefined at normal sandboxes
    },
    env_whitelist={
      "LANG",
      "LC_ALL",
    },
    -- also define some essential env variables for sandboxed env
    env_set={
      {"PATH","/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11"},
      defaults.env.set_xdg_runtime,
      defaults.env.set_home,
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
      defaults.mounts.sys_mount,
      defaults.mounts.resolvconf_mount,
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"etc"),"/etc"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"boot"),"/boot"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"root"),"/root"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"run"),"/run"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"srv"),"/srv"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"opt"),"/opt"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"tmp"),"/tmp"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"var"),"/var"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"home"),"/home"},
      {prio=10,"bind",loader.path.combine(tunables.chrootdir,"selinux"),"/selinux"},
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

fakeroot_shell={
  exec="/fixups/fakeroot-session-starter.sh",
  path="/root",
  args={"opensuse-42.2","/bin/bash","--login"},
  env_set={
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
  desktop={
    name = "FakeRoot Shell for external opensuse chroot",
    comment = "shell for sandbox uid "..config.sandbox_uid,
    icon = "terminal",
    terminal = true,
    startupnotify = false,
  },
}
