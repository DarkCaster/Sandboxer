-- this is an example config that allows to run steam client in sandbox.
-- using external debian chroot (debian jessie), use download-debian-jessie-chroot.sh to download and prepare rootfs archive.
-- see steam-howto.txt for info about other preparations needed to install and run steam inside sandbox.

-- using debian-sandbox.cfg.lua config file as base

-- 3D acceleration was tested on Intel and NVidia graphics. In order to use acceleration with nvidia cards, you should install nvidia driver components (same version as used at host system) into debian chroot used as base for this sandbox (you can manage chroot with "sandboxer debian-setup.cfg.lua fakeroot_shell" command, see debian-setup.cfg.lua example for more info)

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters from "tunables" table that will affect some values from "defaults" table after running recalculate
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-steam")
  defaults.recalculate_orig()
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- enable resolvconf feature
table.insert(sandbox.features,"resolvconf")
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.resolvconf_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- insert sandbox build commands
table.insert(sandbox.setup.commands,{'mkdir -p "${cfg[tunables.auto.user_path]}/libs/i386"'})
table.insert(sandbox.setup.commands,{'mkdir -p "${cfg[tunables.auto.user_path]}/libs/x86_64"'})

-- add connection to system dbus service. used by steam at startup to detect network-manager status
table.insert(sandbox.setup.mounts,defaults.mounts.dbus_system_mount)

-- mount optional user-folder with various helper-stuff
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"games"),"/home/sandboxer/games"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"winetricks_cache"),"/home/sandboxer/.cache/winetricks"})

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

-- following profile tested on debian jessie based sandbox, see steam-howto.txt for more info about sandbox preparation
steam_native={
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
  log_stderr=loader.path.combine(loader.workdir,"steam.native.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"steam.native.out.log"),
  desktop={
    name = "Steam Client (native)",
    comment = "Steam for sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.chrootdir,"usr/share/pixmaps/steam.png"),
    terminal = false,
    startupnotify = false,
  },
}

steam_runtime={
  exec="/usr/bin/steam",
  path="/home/sandboxer",
  env_set={
    {"STEAM_RUNTIME","1"},
  },
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true, -- for now it is needed for logging to work
  log_stderr=loader.path.combine(loader.workdir,"steam.runtime.err.log"),
  log_stdout=loader.path.combine(loader.workdir,"steam.runtime.out.log"),
  desktop={
    name = "Steam Client (steam runtime)",
    comment = "Steam for sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.chrootdir,"usr/share/pixmaps/steam.png"),
    terminal = false,
    startupnotify = false,
  },
}

-- profiles for running steam on ubuntu_bionic, see steam-howto.txt for more info about sandbox preparation
copy_missing_libs_bionic={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","\
  ln -s /lib/i386-linux-gnu/libudev.so.1 ~/libs/i386/libudev.so.0;\
  ln -s /lib/x86_64-linux-gnu/libudev.so.1 ~/libs/x86_64/libudev.so.0;\
  find ~/.steam/ubuntu12_32/steam-runtime/i386 -type f,l -name libappindicator.so.1* -exec cp -v {} ~/libs/i386 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/i386 -type f,l -name libindicator.so.7* -exec cp -v {} ~/libs/i386 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/i386 -type f,l -name libpng12.so.0* -exec cp -v {} ~/libs/i386 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/i386 -type f,l -name libva.so.1* -exec cp -v {} ~/libs/i386 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/i386 -type f,l -name libva-x11.so.1* -exec cp -v {} ~/libs/i386 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/amd64 -type f,l -name libappindicator.so.1* -exec cp -v {} ~/libs/x86_64 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/amd64 -type f,l -name libindicator.so.7* -exec cp -v {} ~/libs/x86_64 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/amd64 -type f,l -name libpng12.so.0* -exec cp -v {} ~/libs/x86_64 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/amd64 -type f,l -name libva.so.1* -exec cp -v {} ~/libs/x86_64 \\;\
  find ~/.steam/ubuntu12_32/steam-runtime/amd64 -type f,l -name libva-x11.so.1* -exec cp -v {} ~/libs/x86_64 \\;\
  "},
  attach=true,
}

steam_ubuntu_native={
  exec="/usr/games/steam",
  path="/home/sandboxer",
  env_set=steam_native.env_set,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop=steam_native.desktop,
}

steam_ubuntu_runtime={
  exec="/usr/games/steam",
  path="/home/sandboxer",
  env_set=steam_runtime.env_set,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
  desktop=steam_runtime.desktop,
}