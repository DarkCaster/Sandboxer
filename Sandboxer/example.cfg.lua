-- example config for sandbox and exec profile

sandbox =
{
	-- lockdown settings.
	-- missing options will be set to default values (listed here)
	lockdown =
	{
		user=true,
		ipc=true,
		pid=true,
		net=false,
		uts=true,
		cgroup=false,
		-- uid=1000, -- variable not defined by default
		-- gid=1000, -- variable not defined set by default
		-- hostname=sandbox, -- not set by default
	},
	-- integration options.
	-- allow applications inside sandbox to use some features from host user session
	integration =
	{
		pulse=true, -- TODO
		x11=true, -- TODO
	},
	-- sandbox features
	-- some service features or subsystems that applications may use inside sandbox
	features =
	{
		dbus=true, -- TODO
	},
}

shell =
{

}
