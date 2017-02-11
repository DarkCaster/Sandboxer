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

-- some tunable defaults:

-- base directory: defaults.basedir
-- you may change this in case of debug.
-- default value is config.ctldir - automatically generated sandbox directory unique to config file, located in /tmp.
-- base directory for all internal sandbox control stuff, used by sandboxer system,
-- this directory will be automatically created\removed by sandboxer system.
-- automatically generated directories and files also stored here.
-- this directory should be unique for each sandbox config file, and should be placed on tmpfs.
-- example:
-- defaults.basedir=config.ctldir -- default
-- defaults.basedir=loader.path.combine(loader.workdir,"basedir-"..config.sandbox_uid)

-- chroot construction dir: defaults.chrootdir
-- used by defaults.commands\default.bwrap defines
-- this directory is set (chdir) before running sandbox.setup.commands blocks, and when applying some features
-- example:
-- defaults.chrootdir=loader.path.combine(defaults.basedir,"chroot") -- default
-- defaults.chrootdir=loader.path.combine(loader.workdir,"chroot-"..config.sandbox_uid)

-- user id: defaults.uid
-- numeric user id, used in various sandbox.setup.commands and when applying some features
-- may be used when launching bwrap with custom uid\gid option
-- default value - user id of user launched sandboxer.sh script
-- example:
-- defaults.uid=config.uid -- default

-- group id id: defaults.gid
-- similiar to user id (above)
-- default value - effective gid of user launched sandboxer.sh script
-- example:
-- defaults.gid=config.gid -- default

-- username, used inside sandbox: defaults.user
-- username, string, used by some sandbox.setup.commands blocks (for example defaults.commands.pwd command)
-- default value - sandboxer
-- example:
-- defaults.user="sandboxer" -- default

-- persistent directory for userdata: defaults.datadir
-- used by some sandbox.setup.commands and sandbox.bwrap blocks.
-- stores user's home and configs, persistent cache, persistent tmp (/var/tmp)
-- default value - unique directory based on config file name + it's fs location.
-- this directory created by default in the same directory as current config file. 
-- example:
-- defaults.datadir=loader.path.combine(loader.workdir,"userdata-"..config.sandbox_uid) -- default
-- defaults.datadir=loader.path.combine(os.getenv("HOME"),"sandboxer-"..config.sandbox_uid)

-- if you changed ANY of tunable defaults (above), you MUST run defaults.recalculate() function here,
-- this will update and recalculate all deps used by other defaults definitions and setup commands.
-- uncomment this if you changed anything above:
-- defaults.recalculate()

sandbox =
{
	-- sandbox features and host-integration stuff that require some complex or dynamic preparations.
	-- features are enabled in order of appearance, feature name may contain only lowercase letters, numbers and underscores.
	features =
	{
		"dbus", -- run dbus-session instance inside sandbox, and allow other sandbox sessions to use it
		"gvfs_fix", -- fix gvfs setup inside sandbox, and strip down it's features to bare minimum. TODO: find out what removed gvfs features works inside sandbox and reenable it
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
		-- security key used in hash calculation process for all communications between sandbox and host
		-- for now it is just a 32-bit unsigned number, it may change in future
		security_key=42,  -- optional

		-- use static build of executor binary. may be useful for use in very restrictive, minimalistic or other custom chroots
		static_executor=false, -- optional, will be set automatically to false if missing.

		-- table with custom user commands, that will be run when creating chroot after tasks from chroot table (see above) is complete.
		-- current dir will be set to chroot directory, that is located at sandbox.setup.basedir/chroot
		-- custom command-groups executed in order of appearence.
		-- this can be used to dynamically create configuration files and other things to mount inside sandbox later.
		-- command-groups are executed by using eval in context of main sandboxer.sh launcher script. so, be careful!
		-- exit code from command group ($?) is examined, sandboxer.sh will automatically terminate is case of errors ($?!=0)
		commands = -- optional
		{
			defaults.commands.etc_min, -- copy minimal config to defaults.chrootdir
			defaults.commands.etc_dbus, -- copy dbus config to defaults.chrootdir
			defaults.commands.etc_x11, -- copy x11 config to defaults.chrootdir
			-- defaults.commands.etc_full, -- copy full /etc to to defaults.chrootdir
			defaults.commands.pwd, -- generate defaule /etc/passwd and /etc/group files with "sandbox" user (mapped to current uid)
			defaults.commands.home, -- create userdata/home at this config file directory, if missing
			defaults.commands.x11, -- copy .Xauthority, or use xhost utility to allow x11 use inside sandbox. should be run after defaults.commands.home
			defaults.commands.pulse, -- generate pulse audio client configs
			defaults.commands.var_cache, -- create userdata/cache at this config file directory, if missing
			defaults.commands.var_tmp, -- create userdata/tmp at this config file directory, if missing
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
			defaults.env.set_x11, -- export display value from host (and maybe some other values needed for x11)
			defaults.env.set_pulse, -- export variables pointing to pulse socket and pulse cookie
		}
	},
}

-- remaining parameters, applied to bwrap utility in order of appearence.
-- recommended to add mount commands here to form root directory layout for sandboxed application.
-- this table presented here as separate definition in order to be able to use all definitions already done in sandbox table earlier.
sandbox.bwrap =
{
	-- main parameters
	defaults.bwrap.unshare_user,
	defaults.bwrap.unshare_ipc,
	defaults.bwrap.unshare_pid,
	-- defaults.bwrap.unshare_net,
	defaults.bwrap.unshare_uts,
	-- defaults.bwrap.unshare_cgroup,
	-- create some service directories
	defaults.bwrap.run_dir,
	defaults.bwrap.xdg_runtime_dir,
	defaults.bwrap.tmp_dir,
	-- make some essential mounts
	defaults.bwrap.proc_mount, -- /proc, prepared by bwrap (according by unshare_* options)
	defaults.bwrap.dev_mount, -- /dev, prepared and filtered by bwrap
	defaults.bwrap.home_mount, -- mount directory with persistent user-data to /home, created with "defaults.commands.home" (recommended)
	defaults.bwrap.var_cache_mount, -- mount directory with persistent cache to /var/cache, created with "defaults.commands.var_cache" (recommended)
	defaults.bwrap.var_tmp_mount, -- mount directory with persistent cache to /var/cache, created with "defaults.commands.var_tmp" (recommended)
	defaults.bwrap.etc_ro_mount, -- readonly mount etc directory from defaults.chrootdir, constructed with defaults.commands.etc_* commands or created manually
	-- defaults.bwrap.etc_rw_mount, -- read-write mount etc directory from defaults.chrootdir, constructed with defaults.commands.etc_* commands or created manually
	-- defaults.bwrap.host_etc_mount, -- readonly mount host etc directory
	-- other mounts, also essential for normal operation
	-- defaults.bwrap.dbus_system_mount, -- mount dbus system socket from host, may possess a potential security risk.
	-- defaults.bwrap.x11_mount, -- mount x11 socket on host filesystem, required if you want to use host x11 when using defaults.bwrap.unshare_net 
	defaults.bwrap.pulse_mount, -- mount /etc/pulse that contain generated pulseaudio configuration for sandboxed client
	defaults.bwrap.devsnd_mount, -- mount /dev/snd to allow alsa, may be not needed for pure pulseadio client to work
	defaults.bwrap.host_bin_mount, -- readonly mount host /bin directory
	defaults.bwrap.host_usr_mount, -- readonly mount host /usr directory
	defaults.bwrap.host_lib_mount, -- readonly mount host /lib directory
	defaults.bwrap.host_lib64_mount, -- readonly mount host /lib64 directory
	-- defaults.bwrap.bin_ro_mount, -- readonly mount bin directory from defaults.chrootdir, constructed manually
	-- defaults.bwrap.usr_ro_mount, -- readonly mount usr directory from defaults.chrootdir, constructed manually
	-- defaults.bwrap.lib_ro_mount, -- readonly mount lib directory from defaults.chrootdir, constructed manually
	-- defaults.bwrap.lib64_ro_mount, -- readonly mount lib64 directory from defaults.chrootdir, constructed manually
	-- defaults.bwrap.bin_rw_mount, -- readonly mount bin directory from defaults.chrootdir, constructed manually
	-- defaults.bwrap.usr_rw_mount, -- readonly mount usr directory from defaults.chrootdir, constructed manually
	-- defaults.bwrap.lib_rw_mount, -- readonly mount lib directory from defaults.chrootdir, constructed manually
	-- defaults.bwrap.lib64_rw_mount, -- readonly mount lib64 directory from defaults.chrootdir, constructed manually
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

