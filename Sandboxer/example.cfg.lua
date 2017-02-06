-- features marked as "TODO" - are long-term goals,
-- that will be implemented after other features complete and working as intended.

-- example config for sandbox and exec profile
-- following global identifiers (tables) reserved for system use:
--   loader (used by bash-lua-helper), some helper stuff: loader.workdir - base directory of this config file, loader.path.combine(path1,path2,...) - combine path components
--   config (defined by sandboxer, store some dynamic configuration parameters for current session)
--   profile (defined by sandboxer at post-script, will overwrite same define made here)
--   defaults (some sane defaults for current linux distribution to simplify config file creation and improve it's portability across different linux distributions. see sandboxer.pre.lua for more info)
--   dbus (internal profile for dbus feature support)
--   pulse (internal profile for pulseaudio feature support)
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

	-- sandbox features and integration options.
	-- enable\disable some service features or subsystems that applications may use inside sandbox.
	-- some features enables communication with non-sandboxed host components.
	-- missing options will be set to default values listed below.
	features =
	{
		pulse=false, -- TODO
		x11=false, -- TODO
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
		-- TODO: it will be automatically removed when all processes inside sandbox terminated.
		-- TODO: maybe we should not allow user to select control directory at all
		basedir=config.ctldir, -- mandatory

		-- security key used in hash calculation process for all communications between sandbox and host
		-- for now it is just a 32-bit unsigned number, it may change in future
		security_key=42,  -- optional

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
		{
			defaults.custom_commands.etc, -- TODO: move /etc directory population to chroot table (above)
			defaults.custom_commands.pwd, -- generate defaule /etc/passwd and /etc/group files with "sandbox" user (mapped to current uid)
			defaults.custom_commands.home, -- create userdata directory at this config file directory, if missing
			defaults.custom_commands.fontconfig, -- /etc/fonts
		},

		-- blacklist for env variables.
		-- all variables from this list will be unset on start
		env_blacklist =
		{
			defaults.env.blacklist_main,
			defaults.env.blacklist_audio,
			defaults.env.blacklist_desktop,
			defaults.env.blacklist_home,
			defaults.env.blacklist_xdg,
		},

		-- TODO: whitelist for env variables. all env variables not in list will be unset in sandboxed env
		-- opposite to blacklist, blacklist processing will be skipped if env_whitelist is defined (even if it is empty!)
		--
		--env_whitelist =
		--{
		--},

		-- set custom env variables,
		env_set =
		{
			defaults.env.set_home,
			defaults.env.set_xdg_runtime,
			defaults.env.set_x11,
		}
	},
}

-- remaining parameters, applied to bwrap utility in order of appearence.
-- recommended to add mount commands here to form root directory layout for sandboxed application.
-- this table presented here as separate definition in order to be able to use all definitions already done in sandbox table earlier.
sandbox.bwrap =
{
	-- create some service directories
	defaults.bwrap.run_dir,
	defaults.bwrap.xdg_runtime_dir,
	defaults.bwrap.tmp_dir,
	defaults.bwrap.var_tmp_dir,
	-- make some mounts essential for normal operation
	defaults.bwrap.proc_mount, -- /proc
	defaults.bwrap.dev_mount, -- /dev
	defaults.bwrap.dbus_system_mount, -- dbus socket for system events (may be required for some applications), may be used with dbus feature
	defaults.bwrap.x11_mount, -- x11 socket on filesystem. required, when running with net isolation
	defaults.bwrap.home_mount, -- mount directory with persistent user-data to /home, created with "defaults.custom_commands.home" (recommended)
	defaults.bwrap.etc_mount(sandbox.setup.basedir), -- mount etc directory, constructed with "defaults.custom_commands.etc" (highly recommended)
	-- other dirs, needed for application running, TODO: change theese with defaults	
	-- first option will be prepended by "--", all options will be processes as strings
	{"ro-bind","/bin","/bin"},
	{"ro-bind","/usr","/usr"},
	{"ro-bind","/lib","/lib"},
	{"ro-bind","/lib64","/lib64"},
}

-- configuration for applications to run inside this sandbox
-- must be a table with any name that is not already defined for service needs (see this list at the top of this file)
-- some parameters are mandatory, some is optional

shell =
{
	exec="/bin/bash", -- mandatory, absolute path to binary inside sandbox
	path="/", -- optional, chdir to this directory inside sandbox before exec
	args=loader.args, -- optional, argument-list for launched binary inside sandbox. loader.args table contain extra arguments appended to sandboxer.sh
	env_unset={"TERM"}, -- optional, variables list to unset
	env_set= -- optional, variables list to set
	{
		{"TERM",os.getenv("TERM")},
	},
	term_signal=defaults.signals.SIGHUP, -- optional, number. signal, to gracefully terminate binary. will be sent to binary and all other processes from it's session (childs)
	attach=true, -- optional, default value is false. if true - start in attached mode, commander module and sandboxer.sh script will not terminate and it will link stdin\stdout from sandboxed process and current terminal, so user can control running application.
	pty=true, -- optional, default value is false. allocate new pty to executor process in sandbox and target process. useful to run interactive shells inside sandbox. 
	exclusive=false, -- optional, default value is false. exclusive mode - will create io channels with name match to profile name instead of random. refuse to launch this profile if already running
}

