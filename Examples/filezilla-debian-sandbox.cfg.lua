-- example config for filezilla sandbox, which is created on top of external debian\ubuntu chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters from "tunables" table that will affect some values from "defaults" table after running recalculate
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-filezilla")
  tunables.features.pulse_env_alsa_config="auto"
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try","/mnt/data","/mnt/data"})

filezilla={
  exec="/home/sandboxer/filezilla/bin/filezilla",
  path="/home/sandboxer/filezilla",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "Filezilla (in sandbox)",
    comment = "Filezilla browser, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer","filezilla/share/icons/hicolor/480x480/apps","filezilla.png"),
    mimetype = "x-scheme-handler/ftp;",
    field_code="%u",
    terminal = false,
    startupnotify = false,
    categories="Network;GTK;"
  },
}

filezilla_install_tarbz2={
	exec="/bin/bash",
	path="/home/sandboxer",
	args={"-c","rm -rf $HOME/filezilla && img=`find ./installs -name \"FileZilla_*.tar.bz2\"|sort -V|tail -n1` && ( bunzip2 -c \"$img\" | tar xvf - ) && mv $HOME/FileZilla* $HOME/filezilla"},
	term_signal=defaults.signals.SIGTERM,
	attach=true,
	pty=false,
	exclusive=true,
}

filezilla_install_targz=filezilla_install_tarbz2

filezilla_install=filezilla_install_tarbz2
