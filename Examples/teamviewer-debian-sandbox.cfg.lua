-- example config for teamviewer sandbox.
-- you need to use i386-based debian chroot downloaded with download-debian-stretch-i386-chroot.sh script and prepared with debian-setup.cfg.lua config.
-- using debian-sandbox.cfg.lua config file as base

-- if using x86_64 host env you must also use i386 session management utilities by running "sandboxer-download-extra" command.
-- you must also manually install libpng12-0 package from debian jessie (it was removed in stretch distro).
-- see https://packages.debian.org/jessie/libpng12-0 for download links, and install package into debian chroot manually with "dpkg -i" command.

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
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
    icon = loader.path.combine(tunables.datadir,"home","sandboxer","teamviewer","tv_bin","desktop","teamviewer.png"),
    terminal = false,
    startupnotify = false,
    categories="Network;Application;"
  },
}
