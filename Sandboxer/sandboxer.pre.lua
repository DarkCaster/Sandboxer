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

defaults.custom_commands={}
-- TODO: move this to chroot table (not complete yet)

defaults.custom_commands.etc=
{
'mkdir -p "etc"',
'cp -rf "/etc/zsh"* "etc"; true',
'cp "/etc/yp.conf" "etc"; true',
'cp -rf "/etc/X11" "etc"; true',
'cp "/etc/wgetrc" "etc"; true',
'cp "/etc/vimrc" "etc"; true',
'cp "/etc/vdpau_wrapper.cfg" "etc"; true',
'cp "/etc/termcap" "etc"; true',
'cp -rf "/etc/security" "etc"; true',
'cp "/etc/resolv.conf" "etc"; true',
'cp -r "/etc/pulse" "etc"; true',
'cp "/etc/profile" "etc"; true',
'cp -rf "/etc/profile.d" "etc"; true',
'cp "/etc/protocols" "etc"; true',
'cp "/etc/os-release" "etc"; true',
'cp "/etc/nsswitch.conf" "etc"; true',
'cp "/etc/nscd.conf" "etc"; true',
'cp "/etc/networks" "etc"; true',
'rm -f "etc/mtab"; ln -s "/proc/self/mounts" "etc/mtab"',
'cp "/etc/mime.types" "etc"; true',
'cp "/etc/localtime" "etc"; true',
'cp -rf "/etc/ld.so"* "etc"; true',
'cp "/etc/libao.conf" "etc"; true',
'cp "/etc/ksh.kshrc" "etc"; true',
'cp "/etc/krb5.conf" "etc"; true',
'cp -rf "/etc/kde4" "etc"; true',
'cp -rf "/etc/java" "etc"; true',
'cp "/etc/inputrc" "etc"; true',
'cp "/etc/host"* "etc"; true',
'cp "/etc/HOSTNAME" "etc"; true',
'cp "/etc/freshwrapper.conf" "etc"; true',
'cp "/etc/ethers" "etc"; true',
'cp "/etc/drirc" "etc"; true',
'cp "/etc/DIR_COLORS" "etc"; true',
'cp "/etc/dialogrc" "etc"; true',
'cp "/etc/csh"* "etc"; true',
'cp -rf "/etc/ca-certificates" "etc"; true',
'cp -rf "/etc/bash"* "etc"; true',
'cp -rf "/etc/mc" "etc"; true',
'cp "/etc/asound-pulse.conf" "etc"; true',
'cp "/etc/alsa-pulse.conf" "etc"; true',
'cp -rf "/etc/alternatives" "etc"; true',
'cp -rf "/etc/alias"* "etc"; true',
'cp "/etc/adjtime" "etc"; true',
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
'mkdir -p "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid)..'"',
'test ! -d "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"sandbox")..'" && \
 2>/dev/null cp -rf /etc/skel "'..loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid,"sandbox")..'" || \
 true',
}

-- /run directory. TODO: populate it with some things if needed
defaults.custom_commands.run=
{
'mkdir -p "run"'
}

-- create xdg runtime directory, inside custom /run dir
defaults.custom_commands.xdg_runtime=
{
'mkdir -p "'..loader.path.combine("run","user",config.uid)..'"',
'chmod 700 "'..loader.path.combine("run","user",config.uid)..'"',
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

defaults.bwrap={}

defaults.bwrap.home_mount = {"bind",loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid),"/home"}

function defaults.bwrap.etc_mount(basedir)
 return {"ro-bind",loader.path.combine(basedir,"chroot","etc"),"/etc"}
end

function defaults.bwrap.run_mount(basedir)
 return {"bind",loader.path.combine(basedir,"chroot","run"),"/run"}
end

defaults.bwrap.xdg_runtime = {"setenv","XDG_RUNTIME_DIR",loader.path.combine("/run","user",config.uid)}

