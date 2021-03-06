config={}
config.profile=loader.extra[1] -- profile name
config.home_dir=loader.extra[2] -- current $HOME value
config.sandboxer_dir=loader.extra[3] -- directory, where sandboxer.sh script (or binary, maybe, in future) located
config.pwd=loader.extra[4] -- current directory, at the moment when sandboxer was launched
config.sandbox_uid=loader.extra[5] -- unique value generated from sandbox filename and location
config.tmpdir=loader.extra[6] -- temp directory
config.ctldir=loader.extra[7] -- default control directory, where stuff for current sandbox will be created if not overriden
config.uid=loader.extra[8] -- uid of user that started sandboxer.sh
config.gid=loader.extra[9] -- effective gid of user that started sandboxer.sh

-- define some defaults to use inside user-sandbox config files, to make them more portable and simple
-- TODO: make different defaults-sets optimized for different linux-distributions (maintain it in different config files, included there)

tunables={}

-- default values for tunables. do not forget to run defaults.recalculate() if you change them
tunables.basedir=config.ctldir
tunables.chrootdir=loader.path.combine(tunables.basedir,"chroot")
tunables.configdir=loader.path.combine(tunables.basedir,"chroot")
tunables.uid=config.uid
tunables.gid=config.gid
tunables.user="sandboxer"
tunables.datadir=loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid)
tunables.etchost_path="/etc"

defaults={}

-- supported signals enumeration for use with profiles
-- TODO: cleanup
defaults.signals={
  SIGHUP=1,SIGINT=2,SIGQUIT=3,SIGILL=4,SIGTRAP=5,SIGABRT=6,SIGIOT=6,SIGBUS=7,SIGFPE=8,SIGKILL=9,SIGUSR1=10,SIGSEGV=11,SIGUSR2=12,SIGPIPE=13,SIGALRM=14,SIGTERM=15,SIGSTKFLT=16,
  SIGCHLD=17,SIGCONT=18,SIGSTOP=19,SIGTSTP=20,SIGTTIN=21,SIGTTOU=22,SIGURG=23,SIGXCPU=24,SIGXFSZ=25,SIGVTALRM=26,SIGPROF=27,SIGWINCH=28,SIGIO=29,SIGPWR=30,SIGSYS=31,
}

-- chroot build commands container. intended for use inside main config files at sandbox.setup.commands table.
defaults.commands={}

-- container for commands and other configurable stuff for various include scripts. not for direct use in config.
tunables.features={}

-- standard mount entries, intended for use inside main config files at sandbox.mounts table
defaults.mounts={}

-- bwrap command line options container. intended for use inside main config files at sandbox.bwrap table
defaults.bwrap={}

-- chroot environment setup group. intended for use inside main config files at sandbox.setup.env_blacklist and sandbox.setup.env_set tables
defaults.env={}

defaults.env.blacklist_main={
  -- main blacklist, include variables that may leak sensitive information
  -- or will be incorrect inside sandbox because of isolation.
  "DBUS_SESSION_BUS_ADDRESS",
  "FROM_HEADER",
  "GPG_AGENT_INFO",
  "GPG_TTY",
  "MAIL",
  "OLDPWD",
  "SHELL",
  "SHLVL",
  "SSH_AGENT_PID",
  "SSH_ASKPASS",
  "SSH_AUTH_SOCK",
  "WINDOWID",
  "TERM",
  "PAM_KWALLET5_LOGIN",
  "PAM_KWALLET_LOGIN",
  "PROFILEHOME",
  "SHELL_SESSION_ID",
}

defaults.env.blacklist_audio={
  -- blacklist that include variables used to alsa\pulse env setup,
  -- recommended to include if your sandboxed app is not using audio.
  -- may be safely used with pulseaudio feature (it will define all needed variables automatically),
  -- so, it is recommended to include this blacklist in any case
  "ALSA_CONFIG_PATH",
  "AUDIODRIVER",
  "QEMU_AUDIO_DRV",
  "SDL_AUDIODRIVER",
}

defaults.env.blacklist_desktop={
  -- blacklist that include variables set\used by X11 (TODO: wayland?) and DE.
  -- recommended to include if your sandboxed app is console app.
  -- may be safely used with x11 (TODO: wayland) feature (it will define all needed variables automatically),
  -- so, it is recommended to include this blacklist in any case
  "DESKTOP_SESSION",
  "DISPLAY",
  "MATE_DESKTOP_SESSION_ID",
  "SESSION_MANAGER",
  "VDPAU_DRIVER",
  "WINDOWMANAGER",
  "XAUTHLOCALHOSTNAME",
  "XAUTHORITY",
  "XCURSOR_THEME",
  "XKEYSYMDB",
  "XMODIFIERS",
  "XNLSPATH",
  "XSESSION_IS_UP",
  "KDE_FULL_SESSION",
  "KDE_MULTIHEAD",
  "KDE_SESSION_UID",
  "KDE_SESSION_VERSION",
  "KONSOLE_DBUS_SERVICE",
  "KONSOLE_DBUS_SESSION",
  "KONSOLE_DBUS_WINDOW",
  "KONSOLE_PROFILE_NAME",
}

defaults.env.blacklist_home={
  -- blacklist, that include some variables related to currently logged-in user env
  -- use with caution, may brake things if some of this variables not set
  "HOME",
  "USER",
  "INPUTRC",
  "LOGNAME",
  "PROFILEREAD",
}

defaults.env.blacklist_xdg={
  -- blacklist some XDG env variables that may leak some information
  -- recommended to include, especially if your app does not use X11
  "XDG_CURRENT_DESKTOP",
  "XDG_RUNTIME_DIR",
  "XDG_SEAT",
  "XDG_SEAT_PATH",
  "XDG_SESSION_CLASS",
  "XDG_SESSION_DESKTOP",
  "XDG_SESSION_ID",
  "XDG_SESSION_PATH",
  "XDG_SESSION_TYPE",
}

-- main bwrap command line options
defaults.bwrap.unshare_user={prio=0,tag="unshare-user","unshare-user"}
defaults.bwrap.unshare_ipc={prio=0,tag="unshare-ipc","unshare-ipc"}
defaults.bwrap.unshare_pid={prio=0,tag="unshare-pid","unshare-pid"}
defaults.bwrap.unshare_net={prio=0,tag="unshare-net","unshare-net"}
defaults.bwrap.unshare_uts={prio=0,tag="unshare-uts","unshare-uts"}
defaults.bwrap.unshare_cgroup={prio=0,tag="unshare-cgroup","unshare-cgroup"}
defaults.bwrap.unshare_all={prio=0,tag="unshare-all","unshare-all"}
defaults.bwrap.hostname_sandbox={prio=0,tag="hostname","hostname","sandbox"}

-- defines for mounts
defaults.mounts.run_dir={prio=10,tag="run","dir","/run"}
defaults.mounts.tmp_dir={prio=10,tag="tmp","dir","/tmp"}
defaults.mounts.var_dir={prio=10,tag="var","dir","/var"}
defaults.mounts.var_run={prio=15,tag="varrun","symlink","/run","/var/run"}
defaults.mounts.proc_mount={prio=10,tag="proc","proc","/proc"}
defaults.mounts.dev_mount={prio=10,tag="dev","dev","/dev"}
defaults.mounts.system_group={
  prio=10,
  defaults.mounts.run_dir,
  defaults.mounts.tmp_dir,
  defaults.mounts.var_dir,
  defaults.mounts.var_run,
  defaults.mounts.proc_mount,
  defaults.mounts.dev_mount,
}

defaults.mounts.sys_mount={prio=10,tag="sys","ro-bind","/sys","/sys"}

defaults.mounts.host_bin_mount={prio=10,tag="bin","ro-bind","/bin","/bin"}
defaults.mounts.host_usr_mount={prio=10,tag="usr","ro-bind","/usr","/usr"}
defaults.mounts.host_lib_mount={prio=10,tag="lib","ro-bind","/lib","/lib"}
defaults.mounts.host_lib64_mount={prio=10,tag="lib64","ro-bind","/lib64","/lib64"}
defaults.mounts.host_essentials_group={
  prio=10,
  defaults.mounts.host_bin_mount,
  defaults.mounts.host_usr_mount,
  defaults.mounts.host_lib_mount,
  defaults.mounts.host_lib64_mount,
}

defaults.mounts.host_sbin_mount={prio=10,tag="sbin","ro-bind","/sbin","/sbin"}
defaults.mounts.host_var_lib_mount={prio=20,tag="varlib","ro-bind","/var/lib","/var/lib"}

-- service mounts
defaults.mounts.dbus_system_mount={prio=20,tag="dbus","bind","/run/dbus","/run/dbus"}
defaults.mounts.devsnd_mount={prio=20,tag="devsnd","dev-bind","/dev/snd","/dev/snd"}
defaults.mounts.devdri_mount={
  prio=20,
  {tag="devdri","dev-bind-try","/dev/dri","/dev/dri"},
  {tag="devnvidia0","dev-bind-try","/dev/nvidia0","/dev/nvidia0"},
  {tag="devnvidia1","dev-bind-try","/dev/nvidia1","/dev/nvidia1"},
  {tag="devnvidia2","dev-bind-try","/dev/nvidia2","/dev/nvidia2"},
  {tag="devnvidia3","dev-bind-try","/dev/nvidia3","/dev/nvidia3"},
  {tag="devnvidiactl","dev-bind-try","/dev/nvidiactl","/dev/nvidiactl"},
  {tag="devnvidiamodeset","dev-bind-try","/dev/nvidia-modeset","/dev/nvidia-modeset"},
  {tag="devnvidiauvm","dev-bind-try","/dev/nvidia-uvm","/dev/nvidia-uvm"},
  {tag="devnvidiauvmtools","dev-bind-try","/dev/nvidia-uvm-tools","/dev/nvidia-uvm-tools"},
}
defaults.mounts.devinput_mount={prio=20,tag="devinput","dev-bind","/dev/input","/dev/input"}
defaults.mounts.devshm_mount={prio=20,tag="devshm","bind","/dev/shm","/dev/shm"}

-- various tunables for features
tunables.features.dbus_search_prefix="/"
tunables.features.xpra_search_prefix="/"
tunables.features.xpra_use_mmap=false
tunables.features.xpra_show_tray=false
tunables.features.gvfs_fix_search_prefix="/"
tunables.features.gvfs_fix_search_locations={
  '/usr/share/gvfs',
}
tunables.features.gvfs_fix_mounts={
  'archive.mount',
  'cdda.mount',
  'computer.mount',
  'localtest.mount',
  'recent.mount',
  'trash.mount',
}
tunables.features.pulse_env={
  {"AUDIODRIVER","pulseaudio"},
  {"QEMU_AUDIO_DRV","pa"},
  {"SDL_AUDIODRIVER","pulse"},
}
tunables.features.pulse_skip_sanity_checks=false
tunables.features.pulse_force_disable_shm=false
tunables.features.pulse_env_alsa_config=""
tunables.features.x11util_build="default"
tunables.features.x11util_build_alt="default"
tunables.features.x11util_enable=true
tunables.features.resolvconf_fallback_server="8.8.8.8"

-- commands for sandbox chroot construction. rely on dynamic variables, filled by calling defaults.recalculate function
defaults.commands.etc_min={'"$tools_dir/etcgen.sh" "${cfg[tunables.etchost_path]}" "${cfg[tunables.auto.etc_path]}"'}
defaults.commands.etc_full={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  '2>/dev/null cp -rf "${cfg[tunables.etchost_path]}/"* "${cfg[tunables.auto.etc_path]}"; true',
  'rm -f "${cfg[tunables.auto.etc_path]}/mtab"; ln -s "/proc/self/mounts" "${cfg[tunables.auto.etc_path]}/mtab"; true',
}
defaults.commands.etc_dbus={'mkdir -p "${cfg[tunables.auto.etc_path]}"','cp -rf "${cfg[tunables.etchost_path]}/dbus"* "${cfg[tunables.auto.etc_path]}"'}
defaults.commands.etc_x11 ={'mkdir -p "${cfg[tunables.auto.etc_path]}"','cp -rf "${cfg[tunables.etchost_path]}/X11" "${cfg[tunables.auto.etc_path]}"'}
defaults.commands.etc_udev={'mkdir -p "${cfg[tunables.auto.etc_path]}"','cp -rf "${cfg[tunables.etchost_path]}/udev" "${cfg[tunables.auto.etc_path]}"'}
defaults.commands.passwd={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  '"$tools_dir/pwdgen_simple.sh" "${cfg[tunables.user]}" "$uid" "${cfg[tunables.uid]}" "$gid" "${cfg[tunables.gid]}" "${cfg[tunables.auto.chroot_user_path]}" "${cfg[tunables.auto.etc_path]}/passwd" "${cfg[tunables.auto.etc_path]}/group"',
}
defaults.commands.passwd_extended={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  '"$tools_dir/pwdgen.sh" "${cfg[tunables.user]}" "$uid" "${cfg[tunables.uid]}" "$gid" "${cfg[tunables.gid]}" "${cfg[tunables.auto.chroot_user_path]}" "${cfg[tunables.auto.etc_path]}/passwd" "${cfg[tunables.auto.etc_path]}/group"',
}
defaults.commands.resolvconf={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  'cp "/etc/resolv.conf" "${cfg[tunables.auto.etc_path]}/resolv.conf"',
}
defaults.commands.hosts={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  'if [[ -f /etc/hosts ]]; then cp "/etc/hosts" "${cfg[tunables.auto.etc_path]}/hosts"; fi',
}
defaults.commands.hostname={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  'if [[ -f /etc/hostname ]]; then cp "/etc/hostname" "${cfg[tunables.auto.etc_path]}/hostname"; fi',
}
defaults.commands.machineid={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  'echo "$config_uid" > "${cfg[tunables.basedir]}/sandbox_uid"',
  '"$tools_dir/machineidgen.sh" "${cfg[tunables.basedir]}" "${cfg[tunables.auto.etc_path]}/machine-id" "/etc/machine-id" "${cfg[tunables.basedir]}/sandbox_uid"',
}
defaults.commands.machineid_static={
  'mkdir -p "${cfg[tunables.auto.etc_path]}"',
  'echo "$config_uid" > "${cfg[tunables.basedir]}/sandbox_uid"',
  '"$tools_dir/machineidgen.sh" "${cfg[tunables.basedir]}" "${cfg[tunables.auto.etc_path]}/machine-id" "${cfg[tunables.basedir]}/sandbox_uid"',
}
defaults.commands.machineid_host_etc={
  'echo "$config_uid" > "${cfg[tunables.basedir]}/sandbox_uid"',
  'if [[ `2>/dev/null cat "${cfg[tunables.etchost_path]}/machine-id"` =~ ^[a-f0-9]*$ && ! -z `2>/dev/null cat "${cfg[tunables.etchost_path]}/machine-id"` ]]; then true; else rm -f "${cfg[tunables.etchost_path]}/machine-id"; "$tools_dir/machineidgen.sh" "${cfg[tunables.basedir]}" "${cfg[tunables.etchost_path]}/machine-id" "${cfg[tunables.basedir]}/sandbox_uid"; fi',
}
defaults.commands.home={
  'mkdir -p "${cfg[tunables.auto.home_base_path]}"',
  '[[ ! -d ${cfg[tunables.auto.user_path]} ]] && 2>/dev/null cp -rf "${cfg[tunables.etchost_path]}/skel" "${cfg[tunables.auto.user_path]}" || true'
}
defaults.commands.home_gui_config={
  'mkdir -p "${cfg[tunables.auto.home_base_path]}"',
  'if [[ -d ${cfg[tunables.auto.user_path]} ]]; then "$tools_dir/gui_toolkits_conf_copy.sh" "${cfg[tunables.user]}" "${cfg[tunables.auto.chroot_user_path]}" "${cfg[tunables.auto.user_path]}"; else echo "you must run defaults.commands.home_gui_config with and after defaults.commands.home"; false; fi'
}
defaults.commands.var_cache={ 'mkdir -p "${cfg[tunables.auto.varcache_path]}"' }
defaults.commands.var_tmp={ 'mkdir -p "${cfg[tunables.auto.vartmp_path]}"' }

-- (re)create tables that rely on tunable parameters
function defaults.recalculate()
  -- remove possible trailing slash
  tunables.etchost_path=loader.path.combine(tunables.etchost_path)

  -- storage for all automatically generated tunables
  tunables.auto={}
  tunables.auto.etc_path=loader.path.combine(tunables.configdir,"etc_dynamic")
  tunables.auto.home_base_path=loader.path.combine(tunables.datadir,"home")
  if tunables.user=="root" then tunables.auto.home_base_path=tostring(tunables.chrootdir) end
  tunables.auto.chroot_user_path=loader.path.combine("/home",tunables.user)
  if tunables.user=="root" then tunables.auto.chroot_user_path=loader.path.combine("/","root") end
  tunables.auto.user_path=loader.path.combine(tunables.auto.home_base_path,tunables.user)
  tunables.auto.varcache_path=loader.path.combine(tunables.datadir,"cache")
  tunables.auto.vartmp_path=loader.path.combine(tunables.datadir,"tmp")

  defaults.env.set_home={
    {"HOME",tunables.auto.chroot_user_path},
    {"USER",tunables.user},
    {"LOGNAME",tunables.user}
  }
  defaults.env.set_xdg_runtime={ {"XDG_RUNTIME_DIR",loader.path.combine("/run","user",tunables.uid)} }
  defaults.mounts.bin_ro_mount={prio=10,tag="bin","ro-bind",loader.path.combine(tunables.chrootdir,"/bin"),"/bin"}
  defaults.mounts.sbin_ro_mount={prio=10,tag="sbin","ro-bind",loader.path.combine(tunables.chrootdir,"/sbin"),"/sbin"}
  defaults.mounts.usr_ro_mount={prio=10,tag="usr","ro-bind",loader.path.combine(tunables.chrootdir,"/usr"),"/usr"}
  defaults.mounts.lib_ro_mount={prio=10,tag="lib","ro-bind",loader.path.combine(tunables.chrootdir,"/lib"),"/lib"}
  defaults.mounts.lib64_ro_mount={prio=10,tag="lib64","ro-bind",loader.path.combine(tunables.chrootdir,"/lib64"),"/lib64"}
  defaults.mounts.chroot_ro_essentials_group={
    prio=10,
    defaults.mounts.bin_ro_mount,
    defaults.mounts.usr_ro_mount,
    defaults.mounts.lib_ro_mount,
    defaults.mounts.lib64_ro_mount,
  }
  defaults.mounts.bin_rw_mount={prio=10,tag="bin","bind",defaults.mounts.bin_ro_mount[2],"/bin"}
  defaults.mounts.sbin_rw_mount={prio=10,tag="sbin","bind",defaults.mounts.sbin_ro_mount[2],"/sbin"}
  defaults.mounts.usr_rw_mount={prio=10,tag="usr","bind",defaults.mounts.usr_ro_mount[2],"/usr"}
  defaults.mounts.lib_rw_mount={prio=10,tag="lib","bind",defaults.mounts.lib_ro_mount[2],"/lib"}
  defaults.mounts.lib64_rw_mount={prio=10,tag="lib64","bind",defaults.mounts.lib64_ro_mount[2],"/lib64"}
  defaults.mounts.chroot_rw_essentials_group={
    prio=10,
    defaults.mounts.bin_rw_mount,
    defaults.mounts.usr_rw_mount,
    defaults.mounts.lib_rw_mount,
    defaults.mounts.lib64_rw_mount,
  }
  defaults.mounts.etc_ro_mount={prio=10,tag="etc","ro-bind",tunables.auto.etc_path,"/etc"}
  defaults.mounts.etc_rw_mount={prio=10,tag="etc","bind",tunables.auto.etc_path,"/etc"}
  defaults.mounts.host_etc_mount={prio=10,tag="etc","ro-bind",loader.path.combine(tunables.etchost_path),"/etc"}
  defaults.mounts.passwd_mount={
    {prio=20,tag="etcpasswd","ro-bind",loader.path.combine(tunables.auto.etc_path,"passwd"),"/etc/passwd"},
    {prio=20,tag="etcgroup","ro-bind",loader.path.combine(tunables.auto.etc_path,"group"),"/etc/group"},
  }
  defaults.mounts.resolvconf_mount={prio=20,tag="etcresolvconf","ro-bind",loader.path.combine(tunables.auto.etc_path,"resolv.conf"),"/etc/resolv.conf"}
  defaults.mounts.direct_resolvconf_mount={prio=20,tag="etcresolvconf","ro-bind","/etc/resolv.conf","/etc/resolv.conf"}
  defaults.mounts.hosts_mount={prio=20,tag="etchosts","ro-bind-try",loader.path.combine(tunables.auto.etc_path,"hosts"),"/etc/hosts"}
  defaults.mounts.direct_hosts_mount={prio=20,tag="etchosts","ro-bind-try","/etc/hosts","/etc/hosts"}
  defaults.mounts.hostname_mount={prio=20,tag="etchostname","ro-bind-try",loader.path.combine(tunables.auto.etc_path,"hostname"),"/etc/hostname"}
  defaults.mounts.direct_hostname_mount={prio=20,tag="etchostname","ro-bind-try","/etc/hostname","/etc/hostname"}
  defaults.mounts.machineid_mount={prio=20,tag="etcmachineid","ro-bind",loader.path.combine(tunables.auto.etc_path,"machine-id"),"/etc/machine-id"}
  defaults.mounts.xdg_runtime_dir={prio=20,tag="xdgrun","dir",loader.path.combine("/run","user",tunables.uid)}
  defaults.mounts.home_mount={prio=20,tag="home","bind",tunables.auto.home_base_path,"/home"}
  if tunables.user=="root" then defaults.mounts.home_mount={} end
  defaults.mounts.var_cache_mount={prio=20,tag="cache","bind",tunables.auto.varcache_path,"/var/cache"}
  defaults.mounts.var_tmp_mount={prio=20,tag="vartmp","bind",tunables.auto.vartmp_path,"/var/tmp"}
  defaults.mounts.var_lib_mount={prio=20,tag="varlib","ro-bind",loader.path.combine(tunables.chrootdir,"var","lib"),"/var/lib"}
  if config.uid~=tunables.uid then defaults.bwrap.uid={prio=5,tag="uid","uid",tunables.uid} else defaults.bwrap.uid={} end
  if config.gid~=tunables.gid then defaults.bwrap.gid={prio=5,tag="gid","gid",tunables.gid} else defaults.bwrap.gid={} end
  tunables.features.gvfs_fix_dir=loader.path.combine(tunables.configdir,"gvfs_fix")
  tunables.features.pulse_dir=loader.path.combine(tunables.configdir,"pulse")
  tunables.features.alsa_dir=loader.path.combine(tunables.configdir,"alsa")
  tunables.features.fixups_dir=loader.path.combine(tunables.configdir,"fixups")
  tunables.features.envfix_home=tunables.auto.chroot_user_path
  tunables.features.x11host_target_dir=tunables.auto.user_path
  tunables.features.x11host_target_chroot_dir=tunables.auto.chroot_user_path
end

defaults.recalculate()

-- define service profiles

dbus={
  exec="placeholder",
  path="/",
  args={ "--session", "--print-pid", "--print-address" },
  term_signal=defaults.signals.SIGTERM,
  term_child_only=true,
  attach=true,
  pty=false,
  exclusive=true,
}

xpra={
  exec="placeholder",
  path="/",
  args={
    'start',
    '--socket-dir=/executor/control/xpra',
    '--log-dir=/executor/control/xpra',
    '--log-file=xpra.log',
    '--bind=sock',
    '--pidfile=/executor/control/xpra/xpra.pid',
    '--systemd-run=no',
    '--html=off',
    '--daemon=no',
    '--file-transfer=no',
    '--exit-with-client=no',
    '--remote-logging=no',
    '--mdns=no',
    '--pulseaudio=no',
    '--dbus-proxy=no',
    '--dbus-launch=',
    '--sharing=no',
    '--bell=yes',
    '--speaker=disabled',
    '--microphone=off',
    '--encoding=rgb',
    '--speed=100',
    '--compressors=',
    '--compress=0',
    '--pings=no',
  },
  term_signal=defaults.signals.SIGTERM,
  term_child_only=true,
  attach=false,
  pty=false,
  exclusive=true,
}

x11util={
  exec="/executor/extra/x11util",
  path="/executor/extra",
  term_signal=defaults.signals.SIGTERM,
  term_child_only=true,
  attach=true,
  pty=false,
  exclusive=true,
}

none={
  exec="/bin/true",
  path="/",
  term_signal=defaults.signals.SIGTERM,
  term_child_only=true,
  attach=false,
  pty=false,
  exclusive=false,
}
