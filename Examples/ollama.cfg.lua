-- example config for ollama sandbox, which is created on top of external debian or ubuntu chroot, prepared by debian-setup.cfg.lua

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-ollama-"..config.uid)
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
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- directory with ollama install-archives, "installs" dir must be located at the same path as this config file
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try","/mnt/data","/mnt/data"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

ollama_install={
  exec="/bin/bash",
  path="/tmp",
  args={"-c","img=`find $HOME/installs -name \"ollama-linux-amd64*\"|sort -V|tail -n1` && rm -rf $HOME/ollama && mkdir -p $HOME/ollama && cp $img $HOME/ollama/ollama && chmod -v 755 $HOME/ollama/ollama"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

ollama_service={
  exec="/home/sandboxer/ollama/ollama",
  path="/home/sandboxer/ollama",
  args={"serve"},
  term_signal=defaults.signals.SIGTERM,
  attach=true, -- for gathering stdio-logs via external service manager like systemd
  pty=false, -- pty not needed
  exclusive=true,
  term_on_interrupt=true,
  term_orphans=true,
}

ollama={
  exec="/home/sandboxer/ollama/ollama",
  path="/home/sandboxer/ollama",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true
}

--[[
Below is an example service file for starting this via systemd --user

[Unit]
Description=ollama user service
StartLimitIntervalSec=60
StartLimitBurst=4

[Service]
ExecStart=sandboxer <path to ollama.cfg.lua> ollama_service
ExecStop=sandboxer-term <path to ollama.cfg.lua> 60
ExecStop=sandboxer-kill <path to ollama.cfg.lua>
Restart=on-failure
RestartSec=1
TimeoutStopSec=80
TimeoutStartSec=30

[Install]
WantedBy=desktop.target
]]--
