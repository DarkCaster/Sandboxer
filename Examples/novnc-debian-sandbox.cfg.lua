-- example config for novnc sandbox, which is created on top of external debian chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base

-- you need to install python 2.7 and git inside sandbox in order to run novnc_install and novnc profiles

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-novnc")
  defaults.recalculate_orig()
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
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
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})

-- remove unshare_ipc bwrap param or x11vnc will not work
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)

novnc_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e\
  if [[ ! -e novnc ]]; then\
    git clone https://github.com/novnc/noVNC.git novnc\
  else\
    (cd novnc && git pull)\
  fi\
  if [[ ! -e novnc/utils/websockify ]]; then\
    git clone https://github.com/novnc/websockify novnc/utils/websockify\
  else\
    (cd novnc/utils/websockify && git pull)\
  fi\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}

novnc_standalone={
  exec="/home/sandboxer/novnc/utils/launch.sh",
  path="/home/sandboxer",
  args=loader.args,
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

novnc={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","teardown () {\
      trap 'teardown' TERM HUP INT\
      [[ ! -z $vncpid ]] && echo terminating vnc server && kill -SIGTERM $vncpid\
      [[ ! -z $novncpid ]] && echo terminating novnc && kill -SIGHUP $novncpid\
    }\
    trap 'teardown' TERM HUP INT\
    x11vnc &\
    vncpid=$!\
    novnc/utils/launch.sh &\
    novncpid=$!\
    wait $novncpid\
    wait $vncpid\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true, -- for now it is needed for logging to work
}

acmesh_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e\
  rm -rf ./acme.sh\
  git clone https://github.com/Neilpang/acme.sh.git acme.sh\
  pushd ./acme.sh\
  ./acme.sh --install --nocron\
  popd\
  rm -rf ./acme.sh\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}

acmesh_upgrade={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"--login","-c","$HOME/.acme.sh/acme.sh --upgrade"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}

function concat_nil(str,k)
  if k ~= nil then
    return str .. k
  else
    return str
  end
end

acmesh_issue={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"--login","-c",concat_nil("mkdir -p $HOME/keys && $HOME/.acme.sh/acme.sh --cert-file $HOME/keys/cert --key-file $HOME/keys/key --ca-file $HOME/keys/ca --fullchain-file $HOME/keys/fullchain --days 180 --keylength 4096 --accountkeylength 4096 --issue --standalone --tlsport 63001 --httpport 63000 -d ",loader.args[1])},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}

acmesh_test_issue={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"--login","-c",concat_nil("mkdir -p $HOME/keys && $HOME/.acme.sh/acme.sh --cert-file $HOME/keys/cert --key-file $HOME/keys/key --ca-file $HOME/keys/ca --fullchain-file $HOME/keys/fullchain --days 180 --keylength 4096 --accountkeylength 4096 --staging --issue --standalone --tlsport 63001 --httpport 63000 -d ",loader.args[1])},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}

acmesh_renew={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"--login","-c","$HOME/.acme.sh/acme.sh --force --renew-all --standalone --tlsport 63001 --httpport 63000"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}

acmesh_test_renew={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"--login","-c","$HOME/.acme.sh/acme.sh --force --renew-all --staging --standalone --tlsport 63001 --httpport 63000"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}
