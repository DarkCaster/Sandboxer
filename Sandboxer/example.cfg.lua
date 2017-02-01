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
		-- uid=1000,
		-- gid=1000,
		-- hostname=sandbox,
	},


}

shell =
{

}
