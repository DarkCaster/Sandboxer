config={}
config.profile = loader.extra[1]
config.home_dir = loader.extra[2]
config.sandboxer_dir = loader.extra[3]
config.pwd = loader.extra[4]
config.sandbox_uid = loader.extra[5]
config.tmpdir = loader.extra[6]
config.ctldir = loader.extra[7]
config.uid = loader.extra[8]
config.gid = loader.extra[9]

-- define some defaults to use inside user-sandbox config files, to make them more portable and simple
-- TODO: make different defaults-sets optimized for different linux-distributions (maintain it in different config files, included there)

defaults={}

-- base directory

-- you may change this in case of debug.
-- default value is config.ctldir - automatically generated sandbox directory unique to config file, located in /tmp.
-- base directory for all internal sandbox control stuff, used by sandboxer system,
-- this directory will be automatically created\removed by sandboxer system.
-- automatically generated directories and files also stored here.
-- this directory should be unique for each sandbox config file, and should be placed on tmpfs.
-- TODO: it will be automatically removed when all processes inside sandbox terminated.

defaults.basedir=config.ctldir

-- signals list
defaults.signals=
{
SIGHUP=1,
SIGINT=2,
SIGQUIT=3,
SIGILL=4,
SIGTRAP=5,
SIGABRT=6,
SIGIOT=6,
SIGBUS=7,
SIGFPE=8,
SIGKILL=9,
SIGUSR1=10,
SIGSEGV=11,
SIGUSR2=12,
SIGPIPE=13,
SIGALRM=14,
SIGTERM=15,
SIGSTKFLT=16,
SIGCHLD=17,
SIGCONT=18,
SIGSTOP=19,
SIGTSTP=20,
SIGTTIN=21,
SIGTTOU=22,
SIGURG=23,
SIGXCPU=24,
SIGXFSZ=25,
SIGVTALRM=26,
SIGPROF=27,
SIGWINCH=28,
SIGIO=29,
SIGPWR=30,
SIGSYS=31,
}

defaults.custom_commands={}
-- TODO: move this to chroot table (not complete yet)

defaults.custom_commands.etc=
{
'mkdir -p "etc"',
'2>/dev/null cp -rf "/etc/zsh"* "etc"; true',
'2>/dev/null cp "/etc/yp.conf" "etc"; true',
'2>/dev/null cp "/etc/wgetrc" "etc"; true',
'2>/dev/null cp "/etc/vimrc" "etc"; true',
'2>/dev/null cp "/etc/vdpau_wrapper.cfg" "etc"; true',
'cp "/etc/termcap" "etc"',
'2>/dev/null cp -rf "/etc/security" "etc"; true',
'cp "/etc/resolv.conf" "etc"',
'2>/dev/null cp -r "/etc/pulse" "etc"; true',
'cp "/etc/profile" "etc"',
'cp -rf "/etc/profile.d" "etc"',
'cp "/etc/protocols" "etc"',
'2>/dev/null cp "/etc/os-release" "etc"; true',
'cp "/etc/nsswitch.conf" "etc"',
'cp "/etc/nscd.conf" "etc"',
'2>/dev/null cp "/etc/networks" "etc"; true',
'rm -f "etc/mtab"; ln -s "/proc/self/mounts" "etc/mtab"',
'2>/dev/null cp "/etc/mime.types" "etc"; true',
'cp "/etc/localtime" "etc"',
'cp -rf "/etc/ld.so"* "etc"',
'cp "/etc/manpath.config" "etc"',
'2>/dev/null cp "/etc/libao.conf" "etc"; true',
'2>/dev/null cp "/etc/ksh.kshrc" "etc"; true',
'2>/dev/null cp "/etc/krb5.conf" "etc"; true',
'2>/dev/null cp -rf "/etc/kde4" "etc"; true',
'2>/dev/null cp -rf "/etc/java" "etc"; true',
'2>/dev/null cp "/etc/inputrc" "etc"; true',
'cp "/etc/host"* "etc"',
'cp "/etc/HOSTNAME" "etc"',
'2>/dev/null cp "/etc/freshwrapper.conf" "etc"; true',
'2>/dev/null cp "/etc/ethers" "etc"; true',
'2>/dev/null cp "/etc/drirc" "etc"; true',
'2>/dev/null cp "/etc/DIR_COLORS" "etc"; true',
'2>/dev/null cp "/etc/dialogrc" "etc"; true',
'2>/dev/null cp "/etc/csh"* "etc"; true',
'2>/dev/null cp -rf "/etc/ca-certificates" "etc"; true',
'2>/dev/null cp -rf "/etc/bash"* "etc"; true',
'2>/dev/null cp -rf "/etc/mc" "etc"; true',
'2>/dev/null cp "/etc/asound-pulse.conf" "etc"; true',
'2>/dev/null cp "/etc/alsa-pulse.conf" "etc"; true',
'2>/dev/null cp -rf "/etc/alternatives" "etc"; true',
'2>/dev/null cp -rf "/etc/alias"* "etc"; true',
'2>/dev/null cp "/etc/adjtime" "etc"; true',
'2>/dev/null cp -rf "/etc/less"* "etc"; true',
}

defaults.custom_commands.pwd=
{
'mkdir -p "etc"',
-- passwd and group files generation
'getent passwd root nobody > "etc/passwd"',
'echo "sandbox:x:'..config.uid..':'..config.gid..':sandbox:/home/sandbox:/bin/bash" >> "etc/passwd"',
'getent group root nobody nogroup > "etc/group"',
'echo "sandbox:x:'..config.gid..':" >> "etc/group"',
}

defaults.custom_commands.home=
{
'mkdir -p "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"home")..'"',
'test ! -d "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"home","sandbox")..'" && \
 2>/dev/null cp -rf /etc/skel "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"home","sandbox")..'" || \
 true',
 -- TODO: move to X11 feature
 'cp "$HOME/.Xauthority" "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"home","sandbox",".Xauthority")..'"',
}


defaults.custom_commands.var_cache=
{
'mkdir -p "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"cache")..'"',
}

defaults.custom_commands.var_tmp=
{
'mkdir -p "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"tmp")..'"',
}

defaults.env={}

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
-- use this when "defaults.custom_commands.pwd" used when constructing sandbox (recommended)
-- also define some env variables normally only defined when launching "login" shell
-- (it is usually overkill for sandbox and it may also expose some unneded env variables unset earlier by blacklist feature)
 {"HOME","/home/sandbox"},
 {"PATH","/usr/bin:/bin:/usr/bin/X11"},
 {"USER","sandbox"},
 {"INPUTRC","/home/sandbox/.inputrc"},
 {"LOGNAME","sandbox"}
}

defaults.env.set_xdg_runtime=
{
 {"XDG_RUNTIME_DIR",loader.path.combine("/run","user",config.uid)},
}

defaults.bwrap={}

defaults.bwrap.home_dir = {"dir","/home/sandbox"}

defaults.bwrap.home_mount = {"bind",loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"home"),"/home"}

defaults.bwrap.var_cache_mount = {"bind",loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"cache"),"/var/cache"}

defaults.bwrap.var_tmp_mount = {"bind",loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"tmp"),"/var/tmp"}

defaults.bwrap.etc_mount = {"ro-bind",loader.path.combine(defaults.basedir,"chroot","etc"),"/etc"}

defaults.bwrap.run_dir = {"dir","/run"}

defaults.bwrap.xdg_runtime_dir = {"dir", loader.path.combine("/run","user",config.uid)}

defaults.bwrap.tmp_dir = {"dir","/tmp"}

defaults.bwrap.proc_mount = {"proc","/proc"}

defaults.bwrap.dev_mount = {"dev","/dev"}

-- defines for features, fore use in main script

defaults.features={}

defaults.features.dbus_conf_copy=
{
'mkdir -p "etc"',
'cp -rf "/etc/dbus"* "etc"',
}

defaults.features.dbus_system_mount = {"bind","/run/dbus","/run/dbus"}

defaults.features.x11_mount = {"bind","/tmp/.X11-unix","/tmp/.X11-unix"}

defaults.features.x11_conf_copy=
{
'mkdir -p "etc"',
'cp -rf "/etc/X11" "etc"',
'cp -rf "/etc/fonts" "etc"',
}

defaults.features.gvfs_fix_conf=
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

defaults.features.gvfs_fix_mount = {"ro-bind",loader.path.combine(defaults.basedir,"chroot","gvfs_fix"),"/usr/share/gvfs"}

-- define service profiles

dbus =
{
exec="/bin/dbus-daemon",
path="/",
args={ "--session", "--print-pid", "--print-address" },
term_signal=defaults.signals.SIGTERM,
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

