-- features marked as "TODO" - are long-term goals,
-- that will be implemented after other features complete and working as intended.

-- example config for sandbox and exec profile
-- following global identifiers (tables) reserved for system use:
--   loader (used by bash-lua-helper), some helper stuff: loader.workdir - base directory of this config file, loader.path.combine(path1,path2,...) - combine path components
--   config (defined by sandboxer, store some dynamic configuration parameters for current session)
--   profile (defined by sandboxer at post-script, will overwrite same define made here)
--   TODO: default (some sane defaults for current linux distribution to simplify config file creation and improve it's portability across different linux distributions)
-- try not to redefine this identifiers accidentally (TODO add some more checks)

sandbox =
{
	-- lockdown settings.
	-- missing options will be set to default values listed below
	lockdown =
	{
		user=true,
		ipc=true,
		pid=true,
		net=false,
		uts=true,
		cgroup=false,
		-- uid=1000, -- variable not defined by default, will not be set at all if missing
		-- gid=1000, -- variable not defined set by default, will not be set at all if missing
		-- hostname=sandbox, -- not set by default, will not be set at all if missing
	},

	-- integration options.
	-- allow applications inside sandbox to use some features from host user session
	-- missing options will be filled by default values listed below
	integration =
	{
		pulse=true, -- TODO
		x11=true, -- TODO
	},

	-- sandbox features
	-- some service features or subsystems that applications may use inside sandbox
	-- missing options will be set to default values listed below
	features =
	{
		dbus=true, -- TODO
	},

	-- main sandbox setup parameters such as:
	--   location of control and temporary directories;
	--   persistent user data locations;
	--   some chroot construction parameters, dynamic creation and fillup of data directories
	--   commander\executor options
	--
	-- this table and most of it's parameters are mandatory
	setup =
	{
		-- base directory for all internal sandbox control stuff, used by sandboxer system,
		-- this directory will be automatically created\removed by sandboxer system.
		-- automatically generated directories and files also stored here.
		-- this directory should be unique for each sandbox config file, and should be placed on tmpfs.
		-- it will be automatically removed when all processes inside sandbox terminated.
		basedir=config.ctldir, -- mandatory

		-- use static build of executor binary. may be useful for use in very restrictive, minimalistic or other custom chroots
		static_executor=false, -- optional, will be set automatically to false if missing.

		-- TODO: table with definitions to create and populate chroot directories to mount it later inside sandbox
		-- there will be various commands to help with creating your stuff:
		--   directory creation,
		--   files create\copy with optional inplace sed\grep process,
		--   directory tree copy, with various search patterns\glob\etc ...
		--   ...
		chroot = -- optional
		{
		},

		-- table with custom user commands, that will be run when creating chroot after tasks from chroot table (see above) is complete.
		-- current dir will be set to chroot directory, that is located at sandbox.setup.basedir/chroot
		-- custom command-groups executed in order of appearence.
		-- this can be used to dynamically create configuration files and other things to mount inside sandbox later.
		-- command-groups are executed by using eval in context of main sandboxer.sh launcher script. so, be careful!
		-- exit code from command group ($?) is examined, sandboxer.sh will automatically terminate is case of errors ($?!=0)
		custom_commands = -- optional
		{	-- TODO: move this to chroot table (above)
			{
			'mkdir -p "etc"',
			'cp -r "/etc/zsh"* "etc"; true',
			'cp "/etc/yp.conf" "etc"; true',
			'cp -r "/etc/X11" "etc"; true',
			'cp "/etc/wgetrc" "etc"; true',
			'cp "/etc/vimrc" "etc"; true',
			'cp "/etc/vdpau_wrapper.cfg" "etc"; true',
			'cp "/etc/termcap" "etc"; true',
			'cp -r "/etc/security" "etc"; true',
			'cp "/etc/resolv.conf" "etc"; true',
			'cp -r "/etc/pulse" "etc"; true',
			'cp "/etc/profile" "etc"; true',
			'cp -r "/etc/profile.d" "etc"; true',
			'cp "/etc/protocols" "etc"; true',
			'cp "/etc/os-release" "etc"; true',
			'cp "/etc/nsswitch.conf" "etc"; true',
			'cp "/etc/nscd.conf" "etc"; true',
			'cp "/etc/networks" "etc"; true',
			'rm -f "etc/mtab"; ln -s "/proc/self/mounts" "etc/mtab"',
			'cp "/etc/mime.types" "etc"; true',
			'cp "/etc/localtime" "etc"; true',
			'cp -r "/etc/ld.so"* "etc"; true',
			'cp "/etc/libao.conf" "etc"; true',
			'cp "/etc/ksh.kshrc" "etc"; true',
			'cp "/etc/krb5.conf" "etc"; true',
			'cp -r "/etc/kde4" "etc"; true',
			'cp -r "/etc/java" "etc"; true',
			'cp "/etc/inputrc" "etc"; true',
			'cp "/etc/host"* "etc"; true',
			'cp "/etc/HOSTNAME" "etc"; true',
			'cp "/etc/freshwrapper.conf" "etc"; true',
			'cp "/etc/ethers" "etc"; true',
			'cp "/etc/drirc" "etc"; true',
			'cp "/etc/DIR_COLORS" "etc"; true',
			'cp "/etc/dialogrc" "etc"; true',
			'cp "/etc/csh"* "etc"; true',
			'cp -r "/etc/ca-certificates" "etc"; true',
			'cp "/etc/asound-pulse.conf" "etc"; true',
			'cp "/etc/alsa-pulse.conf" "etc"; true',
			'cp -r "/etc/alternatives" "etc"; true',
			'cp -r "/etc/alias"* "etc"; true',
			'cp "/etc/adjtime" "etc"; true',
			-- passwd and group files generation
			'getent passwd root nobody > "etc/passwd"',
			'echo "sandbox:x:'..config.uid..':'..config.gid..':sandbox:/home/sandbox:/bin/bash" >> "etc/passwd"',
			'getent group root nobody nogroup > "etc/group"',
			'echo "sandbox:x:'..config.gid..':" >> "etc/group"',
			-- create directory for persistent userdata
			'mkdir -p "'..loader.path.combine(loader.workdir,"userdata")..'"',
			}
		},

		-- blacklist for env variables.
		-- all variables from this list will be unset on start
		env_blacklist =
		{
			"DBUS_SESSION_BUS_ADDRESS",
			"DESKTOP_SESSION",
			"FROM_HEADER",
			"GPG_AGENT_INFO",
			"GPG_TTY",
			"INPUTRC",
			"LOGNAME",
			"MAIL",
			"OLDPWD",
			"SESSION_MANAGER",
			"SSH_AGENT_PID",
			"SSH_ASKPASS",
			"SSH_AUTH_SOCK",
			"WINDOWID",
			"XAUTHORITY",
			"XDG_SEAT",
			"XDG_SEAT_PATH",
		},

		-- TODO: whitelist for env variables. all env variables not in list will be unset in sandboxed env
		env_whitelist =
		{
		},

		-- set custom env variables
		env_set =
		{
		}
	},
}

-- remaining parameters, applied to bwrap utility in order of appearence.
-- recommended to add mount commands here to form root directory layout for sandboxed application.
-- thos table presented here as separate definition in order to be able to use all definitions already done in sandbox table earlier.
sandbox.bwrap =
{
	-- first option will be prepended by "--", all options will be processes as strings
	{"bind",loader.path.combine(loader.workdir,"userdata"),"/home"},
	{"ro-bind",loader.path.combine(sandbox.setup.basedir,"chroot","etc"),"/etc"},
	{"ro-bind","/bin","/bin"},
	{"ro-bind","/usr","/usr"},
	{"ro-bind","/lib","/lib"},
	{"ro-bind","/lib64","/lib64"},
	{"dir","/tmp"},
	{"proc","/proc"},
	{"dev","/dev"},
	{"dir",loader.path.combine("/run","user",config.uid)},
	{"setenv","XDG_RUNTIME_DIR",loader.path.combine("/run","user",config.uid)},
}

-- configuration for applications to run inside this sandbox

shell =
{

}
