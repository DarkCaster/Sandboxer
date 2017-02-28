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
-- default value is config.ctldir - automatically generated sandbox directory unique to config file, located in /tmp (or $TMPDIR if set).
-- base directory for all internal sandbox control stuff, used by sandboxer system,
-- this directory will be automatically created, populated and cleaned up by sandboxer system.
-- this directory MUST be unique for each sandbox config file, and should be placed on tmpfs.
-- this directry may be automatically cleaned up on sandbox shutdown, so do not store any persistent stuff here.
-- example:
-- defaults.basedir=config.ctldir -- default
-- defaults.basedir=loader.path.combine(loader.workdir,"basedir-"..config.sandbox_uid)

-- chroot construction dir: defaults.chrootdir
-- used by builtin defaults.commands and default.bwrap defines.
-- this directory is set (chdir) before running sandbox.setup.commands blocks, and when applying some features.
-- this directory may be deleted on sandbox shutdown, if it is located inside defaults.basedir (default).
-- you can change this parameter if you want to generate your own persistent\non-standard chroot
-- and also want to use some builtin commands to perform some dynamic setup on each run.
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

-- etc directory name inside chroot construction dir: defaults.etcdir_name
-- this dir-name used by various builtin commands for "/etc" generation (sandbox.setup.commands),
-- and predefined "/etc" mount entries for bwrap (sandbox.bwrap).
-- you may override this directory name if you constructing your own "etc" directory inside defaults.chrootdir
-- and do not want accidentally overwrite your own stuff by standard chroot generation routines.
-- this parameter do not affect name of "/etc" mount inside sandbox, but only "etc" directory name inside chroot construction dir.
-- example:
-- defaults.etcdir_name="etc" -- default
-- defaults.etcdir_name="etc_auto"

-- TODO: add descriptions for features tunables:
-- defaults.fixupsdir_name="fixups"
-- defaults.features.gvfs_fix_search_prefix
-- defaults.features.gvfs_fix_search_locations
-- defaults.features.gvfs_fix_mounts

-- if you changed ANY of tunable defaults (above), you MUST run defaults.recalculate() function here,
-- this will update and recalculate all deps used by other defaults definitions and setup commands.
-- uncomment this if you changed anything above:
-- defaults.recalculate()

sandbox={
  -- sandbox features and host-integration stuff that require some complex or dynamic preparations.
  -- features are enabled in order of appearance, feature name may contain only lowercase letters, numbers and underscores.
  features={
    "dbus", -- run dbus-session instance inside sandbox, and allow other sandbox sessions to use it
    "gvfs_fix", -- fix gvfs setup inside sandbox, and strip down it's features to bare minimum. TODO: find out what removed gvfs features works inside sandbox and reenable it
    "pulse",
  },

  -- main sandbox setup parameters such as:
  --   location of control and temporary directories;
  --   persistent user data locations;
  --   some chroot construction parameters, dynamic creation and fillup of data directories
  --   commander\executor options
  --
  -- this table and most of it's parameters are mandatory
  setup={
    -- security key used in hash calculation process for all communications between sandbox and host
    -- for now it is just a 32-bit unsigned number, it may change in future
    security_key=42,  -- optional

    -- use static build of executor binary. may be useful for use in very restrictive, minimalistic or other custom chroots
    static_executor=false, -- optional, will be set automatically to false if missing.

    -- perform control directory cleanup after all sandbox sessions are closed and sandbox is destroyed.
    -- may be disabled for debug purposes. may also decrease time to full sandbox startup that is performed when no sessions currently running
    cleanup_on_exit=true, -- optional, will be set automatically to true if missing.

    -- table with commands, that will be run to create and prepare chroot.
    -- commands defined by "groups", each group is a table with "strings" that will be executed by sandboxer.sh script.
    -- command-groups executed in order of appearence.
    -- current dir will be set to chroot directory (located at sandbox.setup.basedir/chroot) before process any command group.
    -- command-groups are executed by using eval in a forked context, so there is no risk to corrupt main sandboxer.sh state.
    -- this list will execute in parallel with other preparation tasks made by main sandboxer.sh script.
    -- exit code from command group ($?) is examined, sandboxer.sh will automatically terminate is case of errors ($?!=0)
    -- this mechanism should be used to dynamically create configuration files and other things to mount inside sandbox later.
    -- there are several "builtin" commands that sandboxer system supports. all such commands are listed here with it's brief descriptions.
    -- defaults commands may be changed in future, and may vary depending on your distribution or some general setup options above.
    commands={-- optional
      --user command example:
      -- {'mkdir -p "etc"', 'touch "hello"'}
      defaults.commands.etc_min, -- copy minimal config to defaults.chrootdir, should not include system, kernel, and other machine stuff
      defaults.commands.etc_dbus, -- copy dbus config to defaults.chrootdir
      defaults.commands.etc_x11, -- copy x11 config to defaults.chrootdir
      defaults.commands.etc_udev, -- copy /etc/udev config to defaults.chrootdir. may be needed for some apps, may leak some information about current hardware config
      -- defaults.commands.etc_full, -- copy full /etc to to defaults.chrootdir
      defaults.commands.passwd, -- generate default /etc/passwd and /etc/group files with "sandbox" user (mapped to current uid)
      defaults.commands.home, -- create userdata/home at this config file directory, if missing
      defaults.commands.x11, -- copy .Xauthority, or use xhost utility to allow x11 use inside sandbox. should be run after defaults.commands.home
      defaults.commands.var_cache, -- create userdata/cache at this config file directory, if missing
      defaults.commands.var_tmp, -- create userdata/tmp at this config file directory, if missing
    },

    -- blacklist for env variables.
    -- all variables from this list will be unset on start
    env_blacklist={
      defaults.env.blacklist_main,
      defaults.env.blacklist_audio,
      defaults.env.blacklist_desktop,
      defaults.env.blacklist_home,
      defaults.env.blacklist_xdg,
    },

    -- whitelist for env variables. all env variables not in list will be unset in sandboxed env
    -- opposite to blacklist, blacklist processing will be skipped if env_whitelist is defined and enabled (even if it is empty!)
    env_whitelist={
      enabled=false, -- optional, to quick enable\disable whitelist logic. applied only if true
    -- { "HOST",
    -- "INPUTRC", }, -- for now, all entries must be in subtable-blocks
    },

    -- set custom env variables,
    env_set={
      -- setup user env, essential for normal operation (especially, for shells and scripts)
      -- use this when "defaults.commands.passwd" used when constructing sandbox (recommended)
      -- also define some env variables normally only defined when launching "login" shell
      -- (launching login shell is usually overkill for sandbox and it may also expose some unneded env variables unset earlier by blacklist feature)
      defaults.env.set_home,
      defaults.env.set_xdg_runtime,
      defaults.env.set_x11, -- export display value from host (and maybe some other values needed for x11)
    }
  },
}

-- remaining parameters, applied to bwrap utility in order of appearence.
-- recommended to add mount commands here to form root directory layout for sandboxed application.
-- this table presented here as separate definition in order to be able to use all definitions already done in sandbox table earlier.
sandbox.bwrap={
  defaults.bwrap.unshare_user,
  defaults.bwrap.unshare_ipc,
  defaults.bwrap.unshare_pid,
  -- defaults.bwrap.unshare_net,
  defaults.bwrap.unshare_uts,
  -- defaults.bwrap.unshare_cgroup,
  defaults.bwrap.system_group,
  -- defaults.bwrap.run_dir, -- included in "system_group"
  -- defaults.bwrap.tmp_dir, -- included in "system_group"
  -- defaults.bwrap.proc_mount, -- included in "system_group". mount /proc prepared by bwrap (according by unshare_* options)
  -- defaults.bwrap.dev_mount, -- included in "system_group". mount /dev, prepared and filtered by bwrap
  -- defaults.bwrap.var_dir, -- included in "system_group"
  defaults.bwrap.xdg_runtime_dir,
  -- make some essential mounts
  defaults.bwrap.home_mount, -- mount directory with persistent user-data to /home, created with "defaults.commands.home" (recommended)
  defaults.bwrap.var_cache_mount, -- mount directory with persistent cache to /var/cache, created with "defaults.commands.var_cache" (recommended)
  defaults.bwrap.var_tmp_mount, -- mount directory with persistent cache to /var/cache, created with "defaults.commands.var_tmp" (recommended)
  defaults.bwrap.etc_ro_mount, -- readonly mount etc directory from defaults.chrootdir, constructed with defaults.commands.etc_* commands or created manually
  -- defaults.bwrap.etc_rw_mount, -- read-write mount etc directory from defaults.chrootdir, constructed with defaults.commands.etc_* commands or created manually
  -- defaults.bwrap.host_etc_mount, -- readonly mount host etc directory
  -- other mounts, also essential for normal operation
  -- defaults.bwrap.dbus_system_mount, -- mount dbus system socket from host, may possess a potential security risk.
  defaults.bwrap.x11_mount, -- mount x11 socket on host filesystem, required if you want to use host x11 when using defaults.bwrap.unshare_net
  defaults.bwrap.devsnd_mount, -- mount /dev/snd to allow alsa, may be not needed for pure pulseadio client to work
  defaults.bwrap.devdri_mount, -- mount /dev/dri to allow hardware acceleration
  defaults.bwrap.devinput_mount, -- mount /dev/input. may be needed for some apps to detect input devices (joystics?)
  -- TODO: add mounts only to some parts of sys directory only needed for particular apps to work
  defaults.bwrap.sys_mount, -- mount /sys directory (readonly). will leak sensitive information about hw config, but may be needed for some complex multimedia apps to work
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

shell={
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

