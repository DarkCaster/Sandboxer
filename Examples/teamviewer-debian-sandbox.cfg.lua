-- example config for teamviewer sandbox.

-- for teamviewer 12 and earlier:
-- you need to use i386-based debian chroot downloaded with download-debian-chroot.sh script and prepared with debian-setup.cfg.lua config.
-- using debian-sandbox.cfg.lua config file as base
-- if using x86_64 host env you must also use i386 session management utilities by running "sandboxer-download-extra" command.
-- you must also manually install libpng12-0 package from debian jessie (it was removed in stretch distro).
-- see https://packages.debian.org/jessie/libpng12-0 for download links, and install package into debian chroot manually with "dpkg -i" command.

-- NOTE: teamviewer 13 and up is not fully supported:
-- teamviewer's complicated online=detection logic is not working as intended inside sandbox env.
-- this makes it impossible to remote control this computer and login to teamviewer account.
-- outgoing remote control connections, however, should work.

-- for teamviewer 13 and up:
-- tested with "teamviewer 14" on ubuntu 18.04 x86_64 chroot downloaded with download-ubuntu-chroot.sh script.
-- external chroot must be prepared with debian-setup.cfg.lua config (using "sandboxer debian-setup.cfg.lua fakeroot_shell" command)
-- use "tv-setup checklibs" to find out what dependencies must be installed in chroot to run teamviewer

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-teamviewer")
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"dbus")

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- optional mount for directory with teamviewer tarxz archives
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})

teamviewer={
  exec="/home/sandboxer/teamviewer/teamviewer",
  path="/home/sandboxer/teamviewer",
  args={},
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  exclusive=true,
  desktop={
    name = "TeamViewer (in sandbox)",
    comment = "Remote control and meeting solution, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"home","sandboxer","teamviewer","tv_bin","desktop","teamviewer_256.png"),
    terminal = false,
    startupnotify = false,
    categories="Network;Application;"
  },
}

teamviewer_checklibs={
  exec="/home/sandboxer/teamviewer/tv-setup",
  path="/home/sandboxer/teamviewer",
  args={"checklibs"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
}

teamviewer_install_tarxz={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/teamviewer && img=`find ./installs -name \"teamviewer*.tar.xz\"|sort|tail -n1` && ( xz -d -c \"$img\" | tar xvf - )"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}
