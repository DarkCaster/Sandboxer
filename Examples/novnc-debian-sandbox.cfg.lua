-- example config for novnc sandbox, which is created on top of external debian/ubuntu chroot, prepared by debian-setup.cfg.lua
-- using debian-sandbox.cfg.lua config file as base
-- tested with ubuntu 18.04 chroot, created with download-ubuntu-chroot.sh script
-- you need to install the following packages inside ubuntu chroot: python (v2.7), x11vnc, socat, git

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
  rm -rf ./novnc\
  git clone https://github.com/novnc/noVNC.git novnc\
  ###uncomment next line if you have any problems with the latest commit\
  ###( cd novnc && git reset --hard 36bfcb0714ddeb0107933589bc4fc108ad54cd8d )\
  git clone https://github.com/novnc/websockify novnc/utils/websockify\
  ###uncomment next line if you have any problems with the latest commit\
  ###( cd novnc/utils/websockify && git reset --hard f0bdb0a621a4f3fb328d1410adfeaff76f088bfd )\
  sed -i 's|encs.push(encodings.pseudoEncodingQualityLevel0 + 6)|encs.push(encodings.pseudoEncodingQualityLevel0 + 2)|g' novnc/core/rfb.js\
  sed -i 's|encs.push(encodings.pseudoEncodingCompressLevel0 + 2)|encs.push(encodings.pseudoEncodingCompressLevel0 + 6)|g' novnc/core/rfb.js\
  sed -i 's|encs.push(encodings.pseudoEncodingCursor)|if(!this._viewOnly)encs.push(encodings.pseudoEncodingCursor)|g' novnc/core/rfb.js\
  echo \"<head><meta http-equiv=\\\"refresh\\\" content=\\\"0; url=./vnc.html?view_only=1&show_dot=1&resize=scale\\\"/></head>\" > novnc/index.html\
"
},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
}

view_only_pwd_script="view_pass=`< /dev/urandom tr -cd '[:alnum:]' | head -c12`\
echo __BEGIN_VIEWONLY__ > /tmp/x11vnc.passwd\
echo \"$view_pass\" >> /tmp/x11vnc.passwd\
echo \"*** View-only mode ***\"\
echo \"view-only password: $view_pass\"\
"

full_access_pwd_script="pass=`< /dev/urandom tr -cd '[:alnum:]' | head -c12`\
view_pass=`< /dev/urandom tr -cd '[:alnum:]' | head -c12`\
echo \"$pass\" > /tmp/x11vnc.passwd\
echo __BEGIN_VIEWONLY__ >> /tmp/x11vnc.passwd\
echo \"$view_pass\" >> /tmp/x11vnc.passwd\
echo \"*** full-access mode ***\"\
echo \"password: $pass\"\
echo \"view-only password: $view_pass\"\
"
view_only_vnc_script="0</dev/null &>$HOME/x11vnc.log x11vnc -passwdfile rm:/tmp/x11vnc.passwd -shared -viewonly -forever -localhost -nossl -noclipboard -nosetclipboard -threads -safer &\
vncpid=$!\
"

full_access_vnc_script="0</dev/null &>$HOME/x11vnc.log x11vnc -passwdfile rm:/tmp/x11vnc.passwd -shared -forever -localhost -nossl -noclipboard -nosetclipboard -threads -safer &\
vncpid=$!\
"

script_header="set -m\
    wait_with_timeout () {\
      local child_pid=$1\
      local comm_wait=100\
      while [[ -d /proc/$child_pid ]]\
      do\
        [[ $comm_wait -lt 1 ]] && return 1\
        sleep 0.025\
        comm_wait=$((comm_wait-1))\
      done\
      return 0\
    }\
    teardown () {\
      trap '' TERM HUP INT\
      echo waiting for vnc server\
      wait_with_timeout $vncpid || ( echo asking vnc server to terminate && kill -SIGINT $vncpid )\
      echo waiting for novnc\
      wait_with_timeout $novncpid || ( echo asking novnc to terminate; kill -SIGINT $novncpid )\
      wait_with_timeout $vncpid || ( echo terminating vnc server && pkill -g $vncpid -SIGKILL )\
      wait_with_timeout $novncpid || ( echo terminating novnc && pkill -g $novncpid -SIGKILL )\
      exit 0\
    }\
    trap 'teardown' TERM HUP INT\
"

novnc_script="if [[ -f $HOME/keys/cert && -f $HOME/keys/key ]]; then\
       cat $HOME/keys/cert $HOME/keys/key >> $HOME/keys/cert+key\
       0</dev/null &>$HOME/novnc.log ./novnc/utils/launch.sh --ssl-only --listen 63003 --cert $HOME/keys/cert+key &\
     else\
       0</dev/null &>$HOME/novnc.log ./novnc/utils/launch.sh --listen 63002 &\
    fi\
    novncpid=$!\
    wait $novncpid\
    echo novnc process was unexpectedly terminated\
    teardown\
"

novnc_view_only={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", script_header .. view_only_pwd_script .. view_only_vnc_script .. novnc_script},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

novnc_full_access={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c", script_header .. full_access_pwd_script .. full_access_vnc_script .. novnc_script},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
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

-- you must provide domain as argument for issuing LetsEcnrypt certificate
-- example: sandboxer novnc-debian-sandbox.cfg.lua acmesh_issue example.com
-- also, you must forward port 80 traffic from your domain to local port 63000, and port 443 traffic to local port 63001
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
