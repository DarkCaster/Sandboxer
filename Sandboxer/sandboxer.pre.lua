config={}
config.profile = loader.extra[1] -- profile name
config.home_dir = loader.extra[2] -- current $HOME value
config.sandboxer_dir = loader.extra[3] -- directory, where sandboxer.sh script (or binary, maybe, in future) located
config.pwd = loader.extra[4] -- current directory, at the moment when sandboxer was launched
config.sandbox_uid = loader.extra[5] -- unique value generated from sandbox filename and location
config.tmpdir = loader.extra[6] -- temp directory
config.ctldir = loader.extra[7] -- default control directory, where stuff for current sandbox will be created if not overriden
config.uid = loader.extra[8] -- uid of user that started sandboxer.sh
config.gid = loader.extra[9] -- effective gid of user that started sandboxer.sh
config.tools_dir = loader.path.combine(config.sandboxer_dir,"tools") -- tools directory, service scripts and utilities used in sandbox construction located there

-- define some defaults to use inside user-sandbox config files, to make them more portable and simple
-- TODO: make different defaults-sets optimized for different linux-distributions (maintain it in different config files, included there)

defaults={}

-- default values for tunables. do not forget to run defaults.recalculate() if you change them
defaults.basedir=config.ctldir
defaults.chrootdir=loader.path.combine(defaults.basedir,"chroot")
defaults.uid=config.uid
defaults.gid=config.gid
defaults.user="sandboxer"
defaults.datadir=loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid)
defaults.etcdir_name="etc"

-- signals list
defaults.signals=
{
 SIGHUP=1,SIGINT=2,SIGQUIT=3,SIGILL=4,SIGTRAP=5,SIGABRT=6,SIGIOT=6,SIGBUS=7,SIGFPE=8,SIGKILL=9,SIGUSR1=10,SIGSEGV=11,SIGUSR2=12,SIGPIPE=13,SIGALRM=14,SIGTERM=15,SIGSTKFLT=16,
 SIGCHLD=17,SIGCONT=18,SIGSTOP=19,SIGTSTP=20,SIGTTIN=21,SIGTTOU=22,SIGURG=23,SIGXCPU=24,SIGXFSZ=25,SIGVTALRM=26,SIGPROF=27,SIGWINCH=28,SIGIO=29,SIGPWR=30,SIGSYS=31,
}

-- chroot build commands container. intended for use inside main config files at sandbox.setup.commands table.
defaults.commands={}

-- container for commands and other configurable stuff for various include scripts. not for direct use in config.
defaults.features={}

-- bwrap command line options container. intended for use inside main config files at sandbox.bwrap table
defaults.bwrap={}

-- chroot environment setup group. intended for use inside main config files at sandbox.setup.env_blacklist and sandbox.setup.env_set tables
defaults.env={}

defaults.commands.etc_full =
{
 'mkdir -p "etc"',
 '2>/dev/null cp -rf "/etc/"* "etc"; true',
 'rm -f "etc/mtab"; ln -s "/proc/self/mounts" "etc/mtab"; true',
}

defaults.commands.etc_dbus = {'mkdir -p "etc"','cp -rf "/etc/dbus"* "etc"'}

defaults.commands.etc_x11 = {'mkdir -p "etc"','cp -rf "/etc/X11" "etc"','cp -rf "/etc/fonts" "etc"'}

defaults.commands.etc_udev = {'mkdir -p "etc"','cp -rf "/etc/udev" "etc"'}

defaults.commands.pulse =
{
 'mkdir -p "pulse"',
 'echo "autospawn=no" > "pulse/client.conf"',
 'echo "enable-shm=no" >> "pulse/client.conf"',
 'echo "default-server=unix:/etc/pulse/socket" >> "pulse/client.conf"',
 'cat `test -f "$HOME/.pulse-cookie" && echo "$HOME/.pulse-cookie" || echo "$HOME/.config/pulse/cookie"` > "pulse/cookie"',
 'chmod 600 "pulse/cookie"',
 'rm -f "pulse/socket"; true',
 -- TODO: more complex pulseaudio socket detection
 'pulse_socket=""',
 'pulse_socket=`2>/dev/null cat "$HOME/.config/pulse/default.pa" | grep "module-native-protocol-unix" | grep "socket" | cut -d" " -f3 | cut -d"=" -f2`; true',
 'test -z "$pulse_socket" && pulse_socket=/run/user/'..config.uid..'/pulse/native; true', -- TODO: also try use xdg_runtime dir env var
 'ln "$pulse_socket" "pulse/socket"',
 'unset pulse_socket',
}

defaults.env.blacklist_main=
{ -- main blacklist, include variables that may leak sensitive information
-- or will be incorrect inside sandbox because of isolation. (TODO: ability to use subsystems defined by such variables)
-- this list does not include variables for current X11 session and DE,
-- does not include variables regad
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

defaults.env.blacklist_audio=
{ -- blacklist that include variables used to alsa\pulse env setup,
-- recommended to include if your sandboxed app is not using audio.
-- may be safely used with pulseaudio feature (it will define all needed variables automatically),
-- so, it is recommended to include this blacklist in any case
"ALSA_CONFIG_PATH",
"AUDIODRIVER",
"QEMU_AUDIO_DRV",
"SDL_AUDIODRIVER",
}

defaults.env.blacklist_desktop=
{ -- blacklist that include variables set\used by X11 (TODO: wayland?) and DE.
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
"GS_LIB",
"GTK2_RC_FILES",
"GTK_RC_FILES",
"KDE_FULL_SESSION",
"KDE_MULTIHEAD",
"KDE_SESSION_UID",
"KDE_SESSION_VERSION",
"KONSOLE_DBUS_SERVICE",
"KONSOLE_DBUS_SESSION",
"KONSOLE_DBUS_WINDOW",
"KONSOLE_PROFILE_NAME",
}

defaults.env.blacklist_home=
{ -- blacklist, that include some variables related to currently logged-in user env
-- use with caution, may brake things if some of this variables not set
"HOME",
"PATH",
"USER",
"INPUTRC",
"LOGNAME",
"PROFILEREAD",
}

defaults.env.blacklist_xdg=
{ -- blacklist some XDG env variables that may leak some information
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

defaults.env.set_home=
{
-- setup user env, essential for normal operation (especially, for shells and scripts)
-- use this when "defaults.commands.pwd" used when constructing sandbox (recommended)
-- also define some env variables normally only defined when launching "login" shell
-- (launching login shell is usually overkill for sandbox and it may also expose some unneded env variables unset earlier by blacklist feature)
 {"HOME",nil},
 {"PATH","/usr/bin:/bin:/usr/bin/X11"},
 {"USER",nil},
 {"INPUTRC",nil},
 {"LOGNAME",nil}
}

defaults.env.set_xdg_runtime = {{"XDG_RUNTIME_DIR",nil}}

defaults.env.set_x11 = {{"DISPLAY",os.getenv("DISPLAY")}}

if os.getenv("XCURSOR_THEME")~=nil then
 table.insert(defaults.env.set_x11,{"XCURSOR_THEME",os.getenv("XCURSOR_THEME")})
end

defaults.env.set_pulse =
{
 {"PULSE_SERVER","unix:/etc/pulse/socket"},
 {"PULSE_COOKIE","/etc/pulse/cookie"},
 {"ALSA_CONFIG_PATH","/etc/alsa-pulse.conf"},
 {"AUDIODRIVER","pulseaudio"},
 {"QEMU_AUDIO_DRV","pa"},
 {"SDL_AUDIODRIVER","pulse"},
}

-- main bwrap command line options
defaults.bwrap.unshare_user = {prio=0,tag="unshare-user","unshare-user"}
defaults.bwrap.unshare_ipc = {prio=0,tag="unshare-ipc","unshare-ipc"}
defaults.bwrap.unshare_pid = {prio=0,tag="unshare-pid","unshare-pid"}
defaults.bwrap.unshare_net = {prio=0,tag="unshare-net","unshare-net"}
defaults.bwrap.unshare_uts = {prio=0,tag="unshare-uts","unshare-uts"}
defaults.bwrap.unshare_cgroup = {prio=0,tag="unshare-cgroup","unshare-cgroup"}
defaults.bwrap.unshare_all = {prio=0,tag="unshare-all","unshare-all"}
-- essential directories and mounts
defaults.bwrap.run_dir = {prio=10,tag="run","dir","/run"}
defaults.bwrap.tmp_dir = {prio=10,tag="tmp","dir","/tmp"}
defaults.bwrap.var_dir = {prio=10,tag="var","dir","/var"}
defaults.bwrap.proc_mount = {prio=10,tag="proc","proc","/proc"}
defaults.bwrap.dev_mount = {prio=10,tag="dev","dev","/dev"}
defaults.bwrap.system_group =
{
 prio=10,
 defaults.bwrap.run_dir,
 defaults.bwrap.tmp_dir,
 defaults.bwrap.var_dir,
 defaults.bwrap.proc_mount,
 defaults.bwrap.dev_mount,
}

defaults.bwrap.sys_mount = {prio=10,tag="sys","ro-bind","/sys","/sys"}

defaults.bwrap.host_bin_mount = {prio=10,tag="bin","ro-bind","/bin","/bin"}
defaults.bwrap.host_usr_mount = {prio=10,tag="usr","ro-bind","/usr","/usr"}
defaults.bwrap.host_lib_mount = {prio=10,tag="lib","ro-bind","/lib","/lib"}
defaults.bwrap.host_lib64_mount = {prio=10,tag="lib64","ro-bind","/lib64","/lib64"}
defaults.bwrap.host_essentials_group =
{
 prio=10,
 defaults.bwrap.host_bin_mount,
 defaults.bwrap.host_usr_mount,
 defaults.bwrap.host_lib_mount,
 defaults.bwrap.host_lib64_mount,
}

defaults.bwrap.bin_ro_mount = {prio=10,tag="bin","ro-bind",nil,"/bin"}
defaults.bwrap.usr_ro_mount = {prio=10,tag="usr","ro-bind",nil,"/usr"}
defaults.bwrap.lib_ro_mount = {prio=10,tag="lib","ro-bind",nil,"/lib"}
defaults.bwrap.lib64_ro_mount = {prio=10,tag="lib64","ro-bind",nil,"/lib64"}
defaults.bwrap.chroot_ro_essentials_group =
{
 prio=10,
 defaults.bwrap.bin_ro_mount,
 defaults.bwrap.usr_ro_mount,
 defaults.bwrap.lib_ro_mount,
 defaults.bwrap.lib64_ro_mount,
}

defaults.bwrap.bin_rw_mount = {prio=10,tag="bin","bind",nil,"/bin"}
defaults.bwrap.usr_rw_mount = {prio=10,tag="usr","bind",nil,"/usr"}
defaults.bwrap.lib_rw_mount = {prio=10,tag="lib","bind",nil,"/lib"}
defaults.bwrap.lib64_rw_mount = {prio=10,tag="lib64","bind",nil,"/lib64"}
defaults.bwrap.chroot_rw_essentials_group =
{
 prio=10,
 defaults.bwrap.bin_rw_mount,
 defaults.bwrap.usr_rw_mount,
 defaults.bwrap.lib_rw_mount,
 defaults.bwrap.lib64_rw_mount,
}

-- etc
defaults.bwrap.etc_ro_mount = {prio=10,tag="etc","ro-bind",nil,"/etc"}
defaults.bwrap.etc_rw_mount = {prio=10,tag="etc","bind",nil,"/etc"}
defaults.bwrap.host_etc_mount = {prio=10,tag="etc","ro-bind","/etc","/etc"}

-- service mounts
defaults.bwrap.xdg_runtime_dir = {prio=20,tag="xdgrun","dir",nil}
defaults.bwrap.home_mount = {prio=20,tag="home","bind",nil,"/home"}
defaults.bwrap.var_cache_mount = {prio=20,tag="cache","bind",nil,"/var/cache"}
defaults.bwrap.var_tmp_mount = {prio=20,tag="vartmp","bind",nil,"/var/tmp"}
defaults.bwrap.dbus_system_mount = {prio=20,tag="dbus","bind","/run/dbus","/run/dbus"}
defaults.bwrap.x11_mount = {prio=20,tag="x11","bind","/tmp/.X11-unix","/tmp/.X11-unix"}
defaults.bwrap.pulse_mount = {prio=20,tag="pulse","bind",nil,"/etc/pulse"}
defaults.bwrap.devsnd_mount = {prio=20,tag="devsnd","dev-bind","/dev/snd","/dev/snd"}
defaults.bwrap.devdri_mount = {prio=20,tag="devdri","dev-bind","/dev/dri","/dev/dri"}
defaults.bwrap.devinput_mount = {prio=20,tag="devinput","dev-bind","/dev/input","/dev/input"}

-- defines for features, fore use in main script
defaults.features.gvfs_fix_conf =
{
 'mkdir -p "gvfs_fix/remote-volume-monitors"',
 'mkdir -p "gvfs_fix/mounts"',
 'cp "/usr/share/gvfs/mounts/archive.mount" "gvfs_fix/mounts"',
 'cp "/usr/share/gvfs/mounts/cdda.mount" "gvfs_fix/mounts"',
 'cp "/usr/share/gvfs/mounts/computer.mount" "gvfs_fix/mounts"',
 'cp "/usr/share/gvfs/mounts/localtest.mount" "gvfs_fix/mounts"',
 'cp "/usr/share/gvfs/mounts/recent.mount" "gvfs_fix/mounts"',
 'cp "/usr/share/gvfs/mounts/trash.mount" "gvfs_fix/mounts"',
}

defaults.features.gvfs_fix_mount = {"ro-bind",nil,"/usr/share/gvfs"}

function defaults.recalculate()
 local home=loader.path.combine(defaults.datadir,"home")
 local user=loader.path.combine(home,defaults.user)
 local chroot_home=loader.path.combine("/home",defaults.user)

 defaults.commands.etc_min = { loader.path.combine(config.tools_dir,"host_whitelist_etc_gen.sh")..' "'..defaults.etcdir_name..'"' }

 defaults.commands.passwd =
 {
  'mkdir -p "'..defaults.etcdir_name..'"',
  loader.path.combine(config.tools_dir,"pwdgen.sh")..' '..defaults.user..' '..config.uid..' '..defaults.uid..' '..config.gid..' '..defaults.gid..' "'..chroot_home..'" "'..defaults.etcdir_name..'/passwd" "'..defaults.etcdir_name..'/group"',
 }

 defaults.commands.x11 = { 'test -d "'..user..'" -a -f "$HOME/.Xauthority" && cp "$HOME/.Xauthority" "'..user..'" || &>/dev/null xhost "+si:localuser:$USER"; true' }

 defaults.commands.home =
 {
  'mkdir -p "'..home..'"',
  'test ! -d "'..user..'" && 2>/dev/null cp -rf /etc/skel "'..user..'" || true'
 }

 defaults.commands.var_cache = { 'mkdir -p "'..loader.path.combine(defaults.datadir,"cache")..'"' }

 defaults.commands.var_tmp = { 'mkdir -p "'..loader.path.combine(defaults.datadir,"tmp")..'"' }
 
 
 
 
 
 
 
 
 defaults.features.gvfs_fix_mount[2]=loader.path.combine(defaults.chrootdir,"gvfs_fix")
 
 defaults.bwrap.bin_ro_mount[2] = loader.path.combine(defaults.chrootdir,"/bin")
 defaults.bwrap.usr_ro_mount[2] = loader.path.combine(defaults.chrootdir,"/usr")
 defaults.bwrap.lib_ro_mount[2] = loader.path.combine(defaults.chrootdir,"/lib")
 defaults.bwrap.lib64_ro_mount[2] = loader.path.combine(defaults.chrootdir,"/lib64")
 defaults.bwrap.bin_rw_mount[2] = defaults.bwrap.bin_ro_mount[2]
 defaults.bwrap.usr_rw_mount[2] = defaults.bwrap.usr_ro_mount[2]
 defaults.bwrap.lib_rw_mount[2] = defaults.bwrap.lib_ro_mount[2]
 defaults.bwrap.lib64_rw_mount[2] = defaults.bwrap.lib64_ro_mount[2]
 defaults.bwrap.etc_ro_mount[2]=loader.path.combine(defaults.chrootdir,"etc")
 defaults.bwrap.etc_rw_mount[2]=defaults.bwrap.etc_ro_mount[2]
 defaults.bwrap.var_tmp_mount[2]=loader.path.combine(defaults.datadir,"tmp")
 defaults.bwrap.var_cache_mount[2]=loader.path.combine(defaults.datadir,"cache")
 defaults.bwrap.home_mount[2]=loader.path.combine(defaults.datadir,"home")
 defaults.bwrap.xdg_runtime_dir[2]=loader.path.combine("/run","user",defaults.uid)
 defaults.bwrap.pulse_mount[2]=loader.path.combine(defaults.chrootdir,"pulse")
 
 
 defaults.env.set_xdg_runtime[1][2]=loader.path.combine("/run","user",defaults.uid)
 defaults.env.set_home[1][2]=loader.path.combine("/home",defaults.user);
 defaults.env.set_home[3][2]=defaults.user
 defaults.env.set_home[4][2]=loader.path.combine(defaults.env.set_home[1][2],".inputrc");
 defaults.env.set_home[5][2]=defaults.user
end

defaults.recalculate()

-- define service profiles

dbus =
{
exec="placeholder",
path="/",
args={ "--session", "--print-pid", "--print-address" },
term_signal=defaults.signals.SIGTERM,
term_child_only=true,
attach=true,
pty=false,
exclusive=true,
}

pulse =
{
exec="/bin/false", -- TODO
path="/",
term_signal=defaults.signals.SIGTERM,
attach=false,
pty=false,
exclusive=true,
}

