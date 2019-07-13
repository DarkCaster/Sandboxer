-- basic sandbox with various development software on top of external opensuse rootfs.
-- this experimental config may be changed or removed in future.

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-dev")
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"opensuse-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"pulse")

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- mounts
table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/tmp"}) -- needed for QtCreator online installer to work
table.insert(sandbox.setup.mounts,{prio=99,"bind-try","/mnt/data","/mnt/data"})
table.insert(sandbox.setup.mounts,{prio=98,"dev-bind-try","/dev/log","/dev/log"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

shell.term_orphans=true

shell.desktop={
  name = "openSUSE shell",
  generic_name= "openSUSE development env",
  comment = "openSUSE shell, sandbox uid "..config.sandbox_uid,
  icon = "terminal",
  terminal = true,
  startupnotify = false,
  categories="Development;Utility;",
}

-- install "tftp" package and configure port-forwarding from port 69 to port 6969 to use this profile
tftpd={
  exec="/usr/sbin/in.tftpd",
  path="/home/sandboxer/tftp_root",
  args={"--foreground","--address","0.0.0.0:6969","--user","sandboxer","--permissive","--verbose"},
  term_signal=defaults.signals.SIGTERM,
  term_orphans=true,
  term_on_interrupt=true,
  attach=true,
  exclusive=true,
  pty=false
}

-- using monodeveop from this obs project: https://build.opensuse.org/project/show/home:Warhammer40k:Mono:Factory
monodevelop={
  exec="/usr/bin/monodevelop",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  term_orphans=true,
  attach=false,
  pty=false,
  desktop={
    name = "MonoDevelop",
    generic_name = "Integrated Development Environment",
    comment = "MonoDevelop, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.chrootdir,"/usr/share/icons/hicolor/128x128/apps/monodevelop.png"),
    field_code="%F",
    terminal = false,
    startupnotify = true,
    categories="GNOME;GTK;Development;IDE;",
    mimetype = "text/x-csharp;application/x-mds;application/x-mdp;application/x-cmbx;application/x-prjx;application/x-csproj;application/x-vbproj;application/x-sln;application/x-aspx;",
    mime =
    {
      monodevelop='<?xml version="1.0" encoding="UTF-8"?>\
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">\
      <mime-type type="application/x-mds">\
      <sub-class-of type="text/plain"/>\
      <comment xml:lang="en">MonoDevelop solution</comment>\
      <glob pattern="*.mds"/>\
      </mime-type>\
      <mime-type type="application/x-mdp">\
      <sub-class-of type="text/plain"/>\
      <comment xml:lang="en">MonoDevelop project</comment>\
      <glob pattern="*.mdp"/>\
      </mime-type>\
      <mime-type type="application/x-cmbx">\
      <comment xml:lang="en">SharpDevelop solution</comment>\
      <glob pattern="*.cmbx"/>\
      </mime-type>\
      <mime-type type="application/x-prjx">\
      <comment xml:lang="en">SharpDevelop project</comment>\
      <glob pattern="*.prjx"/>\
      </mime-type>\
      <mime-type type="application/x-csproj">\
      <sub-class-of type="text/plain"/>\
      <comment xml:lang="en">Visual Studio .NET C# project</comment>\
      <glob pattern="*.csproj"/>\
      </mime-type>\
      <mime-type type="application/x-vbproj">\
      <sub-class-of type="text/plain"/>\
      <comment xml:lang="en">Visual Studio .NET VB.NET project</comment>\
      <glob pattern="*.vbproj"/>\
      </mime-type>\
      <mime-type type="application/x-sln">\
      <sub-class-of type="text/plain"/>\
      <comment xml:lang="en">Visual Studio .NET Solution</comment>\
      <glob pattern="*.sln"/>\
      </mime-type>\
      <mime-type type="application/x-aspx">\
      <comment xml:lang="en">ASP.NET page</comment>\
      <glob pattern="*.aspx"/>\
      </mime-type>\
      </mime-info>'
    },
  },
}
