-- example config for syncthing sandbox, which is created on top of external debian\ubuntu chroot, prepared by debian-setup.cfg.lua

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-syncthing-"..config.uid)
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"dbus")
loader.table.remove_value(sandbox.features,"gvfs_fix")
loader.table.remove_value(sandbox.features,"pulse")
loader.table.remove_value(sandbox.features,"x11host")

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- remove some unneded mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- directory with syncthing install-archives, "installs" dir must be located at the same path as this config file
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try","/mnt/data/Sync","/sync"})

syncthing_install={
	exec="/bin/bash",
	path="/home/sandboxer",
	args={"-c", "\
	syncthing_dir=\"$HOME/syncthing\"; \
	cd $HOME; \
	[ -f \"$syncthing_dir/syncthing\" ] && echo \"Syncthing binary already installed, doing nothing\" && exit 1; \
	img=`find ./installs -name \"syncthing-linux-*.tar.gz\"|sort -V|tail -n1` && ( gzip -d -c \"$img\" | tar xf - ) && mv \"$HOME/\"syncthing-linux-* \"$syncthing_dir\" && echo \"Extract complete!\"; \
	"},
	term_signal=defaults.signals.SIGTERM,
	attach=true,
	pty=false,
	exclusive=true,
}

syncthing_service={
	exec="/home/sandboxer/syncthing/syncthing",
	path="/home/sandboxer/syncthing",
	args={"serve","--no-browser","--no-restart","--logflags=0"},
	term_signal=defaults.signals.SIGTERM,
	attach=true, -- for gathering stdio-logs via external service manager like systemd
	pty=false, -- pty not needed
	exclusive=true,
	term_on_interrupt=true,
	term_orphans=true,
}

syncthing={
	exec="/home/sandboxer/syncthing/syncthing",
	path="/home/sandboxer/syncthing",
	args={"serve","--no-browser","--no-restart","--logflags=0"},
	term_signal=defaults.signals.SIGTERM,
	attach=true,
	pty=true,
}

--[[
Below is an example service file for starting this via systemd --user

[Unit]
Description=Syncthing
StartLimitIntervalSec=60
StartLimitBurst=4

[Service]
ExecStart=sandboxer <path to syncthing.cfg.lua> syncthing_service
ExecStop=sandboxer-term <path to syncthing.cfg.lua> 60
ExecStop=sandboxer-kill <path to syncthing.cfg.lua>
Restart=on-failure
RestartSec=1
SuccessExitStatus=3 4
RestartForceExitStatus=3 4
TimeoutStopSec=80
TimeoutStartSec=30

[Install]
WantedBy=desktop.target


]]--