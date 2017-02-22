defaults.chrootdir=loader.path.combine(loader.workdir,"ubuntu_chroot")

defaults.user="root"

defaults.uid=0

defaults.gid=0

defaults.recalculate()

sandbox =
{
	setup =
	{
		static_executor=true,
		commands =
		{
			{'rm -f "etc/resolv.conf"', 'cp "/etc/resolv.conf" "etc/resolv.conf"'},
		},
		env_blacklist =
		{
			defaults.env.blacklist_main,
			defaults.env.blacklist_audio,
			defaults.env.blacklist_desktop,
			defaults.env.blacklist_home,
			defaults.env.blacklist_xdg,
		},
		-- set custom env variables,
		env_set =
		{
			{
				{"PATH","/fixups:/usr/sbin:/sbin:/usr/bin:/bin:/usr/bin/X11"},
				{"HOME","/root"},
				{"USER",defaults.user},
				{"LOGNAME",defaults.user}
			},
			defaults.env.set_xdg_runtime,
		}
	},
	bwrap =
	{
		defaults.bwrap.unshare_user,
		defaults.bwrap.unshare_ipc,
		defaults.bwrap.unshare_pid,
		defaults.bwrap.unshare_uts,
		defaults.bwrap.proc_mount,
		defaults.bwrap.dev_mount,
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"etc"),"/etc"},
		defaults.bwrap.xdg_runtime_dir,
		defaults.bwrap.bin_rw_mount,
		defaults.bwrap.usr_rw_mount,
		defaults.bwrap.lib_rw_mount,
		defaults.bwrap.lib64_rw_mount,
		defaults.bwrap.fixups_mount,
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"boot"),"/boot"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"boot"),"/boot"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"root"),"/root"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"run"),"/run"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"sbin"),"/sbin"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"srv"),"/srv"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"opt"),"/opt"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"tmp"),"/tmp"},
		{prio=10,"bind",loader.path.combine(defaults.chrootdir,"var"),"/var"},
		{"uid",defaults.uid},
		{"gid",defaults.gid},
	}
}

shell =
{
	exec="/bin/bash",
	path="/", -- optional, chdir to this directory inside sandbox before exec
	env_unset={"TERM"}, -- optional, variables list to unset
	env_set= -- optional, variables list to set
	{
		{"TERM",os.getenv("TERM")},
	},
	term_signal=defaults.signals.SIGHUP,
	attach=true,
	pty=true,
}
