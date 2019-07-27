-- Config for Travis CI cmdline client
-- https://github.com/travis-ci/travis.rb

-- created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base
-- do not forget to install ruby and ruby-dev packages inside sandbox chroot

defaults.recalculate_orig=defaults.recalculate

function defaults.recalculate()
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-travis")
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"dbus")
loader.table.remove_value(sandbox.features,"gvfs_fix")
loader.table.remove_value(sandbox.features,"pulse")

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- add mounts with sources directory
table.insert(sandbox.setup.mounts,{prio=100,tag="data","bind-try","/mnt/data","/mnt/data"})

shell.term_orphans=true
shell.desktop={
  name = "Travis-CI shell",
  generic_name= "Travis-CI utility",
  comment = "Shell for Travis-CI utility, sandbox uid "..config.sandbox_uid,
  icon = "terminal",
  terminal = true,
  startupnotify = false,
  categories="Development;Utility;",
}
shell.env_set={
  {"TERM",os.getenv("TERM")},
  {"GEM_HOME","/home/sandboxer/gems"},
  {"GEM_PATH","/home/sandboxer/gems"},
}
shell.exec="/bin/bash"
shell.args={"-c","PATH=\"$HOME/gems/bin:$PATH\" /bin/bash -l"}

travis_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  env_set=shell.env_set,
  args={"-c","rm -rf $HOME/gems && ( PATH=\"$HOME/gems/bin:$PATH\" gem install travis )"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
  term_orphans=true,
}
