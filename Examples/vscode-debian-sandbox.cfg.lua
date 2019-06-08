-- example config for vscode-ide sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-vscode-"..config.uid)
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"pulse")

-- remove some mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})
table.insert(sandbox.setup.mounts,{prio=99,"bind","/mnt/data","/mnt/data"})
table.insert(sandbox.setup.mounts,{prio=99,"bind-try",loader.path.combine(loader.workdir,"installs"),"/home/sandboxer/installs"})
table.insert(sandbox.setup.commands,{'[[ ! -L "${cfg[tunables.auto.user_path]}/.local/share/Trash" ]] && mkdir -p "${cfg[tunables.auto.user_path]}/.local/share" && rm -rf "${cfg[tunables.auto.user_path]}/.local/share/Trash" && ln -s "/mnt/data/.Trash-${cfg[tunables.uid]}" "${cfg[tunables.auto.user_path]}/.local/share/Trash"; true'})
-- table.insert(sandbox.setup.mounts,{prio=99,"tmpfs","/tmp"})

-- remove unshare_ipc bwrap param
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

vscode={
  exec="/home/sandboxer/VSCode/code",
  path="/home/sandboxer/VSCode",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=false,
  pty=false,
  desktop={
    name = "VSCode (in sandbox)",
    generic_name = "Visual Studio Code",
    comment = "VSCode, sandbox uid "..config.sandbox_uid,
    icon = loader.path.combine(tunables.datadir,"/home/sandboxer/VSCode/resources/app/resources/linux/code.png"),
    field_code="%f",
    terminal = false,
    startupnotify = false,
    categories="Development;IDE;",
    mimetype = "text/x-vscode-workspace-sandbox",
    mime =
    {
      vscode_workspace='<?xml version="1.0" encoding="UTF-8"?>\
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">\
      <mime-type type="text/x-vscode-workspace-sandbox">\
      <comment>VSCode Workspace</comment>\
      <icon name="text-x-source"/>\
      <glob-deleteall/>\
      <glob pattern="*.code-workspace"/>\
      </mime-type>\
      </mime-info>'
    },
  },
}

vscode_install_targz={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","rm -rf $HOME/VSCode && img=`find ./installs -name \"code-*.tar.gz\"|sort|tail -n1` && ( gunzip -c \"$img\" | tar xvf - ) && mv $HOME/VSCode-* $HOME/VSCode"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}
