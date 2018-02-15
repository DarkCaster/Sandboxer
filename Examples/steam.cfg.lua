-- this is an example config that allows to run steam client in sandbox.
-- using external debian chroot (debian jessie), use download-debian-jessie-chroot.sh to download and prepare rootfs archive.
-- see steam-howto.txt for info about other preparations needed to install and run steam inside sandbox.

-- using debian-sandbox.cfg.lua config file as base

-- there may be some problems with 3d acceleration when using hardware that requires to install external driver and its own version of libGL
-- for now this config is tested with Intel IGP that works with stock driers and libGL library.

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-steam")
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- insert sandbox build commands
table.insert(sandbox.setup.commands,{'mkdir -p "${cfg[tunables.auto.user_path]}/libs/i386"'})
table.insert(sandbox.setup.commands,{'mkdir -p "${cfg[tunables.auto.user_path]}/libs/x86_64"'})

shell={
  exec="/bin/bash",
  args={"-l"},
  path="/",
  env_set={
    {"STEAM_RUNTIME","0"},
    {"LD_LIBRARY_PATH","/home/sandboxer/libs/i386:/home/sandboxer/libs/x86_64"},
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
  desktop={
    name = "Shell for steam sandbox",
    comment = "shell for sandbox uid "..config.sandbox_uid,
    icon = "terminal",
    terminal = true,
    startupnotify = false,
  },
}

steam={
  exec="/usr/bin/steam",
  path="/home/sandboxer",
  env_set={
    {"STEAM_RUNTIME","0"},
    {"LD_LIBRARY_PATH","/home/sandboxer/libs/i386:/home/sandboxer/libs/x86_64"},
  },
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"steam.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"steam.out.log"),
  desktop={
    name = "Sandboxed Steam Client",
    comment = "Steam for sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.chrootdir,"usr/share/pixmaps/steam.png"),
    terminal = false,
    startupnotify = false,
  },
}
