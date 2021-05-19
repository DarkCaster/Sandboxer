-- config for running custom klipper 3D printer firmware suite
-- packages need to be installed:
-- for python2 klipper version: virtualenv python-dev libffi-dev build-essential cmake
-- for python3 klipper version (experimental): virtualenv python3-dev libffi-dev build-essential cmake

-- redefine defaults.recalculate function, that will be called by base config
defaults.recalculate_orig=defaults.recalculate
function defaults.recalculate()
  -- redefine some parameters
  tunables.features.x11host_target_dir="/dev/null"
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-klipper")
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
loader.table.remove_value(sandbox.features,"x11host")

-- remove some unneded mounts from base config
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sbin_ro_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)

-- modify PATH env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})
table.insert(sandbox.setup.mounts,{prio=99,"bind",loader.path.combine(loader.workdir,"configs"),"/home/sandboxer/configs"})
table.insert(sandbox.setup.mounts,{prio=99,"bind",loader.path.combine(loader.workdir,"logs"),"/home/sandboxer/logs"})

-- add bwrap unshare_ipc option
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)
table.insert(sandbox.bwrap,defaults.bwrap.unshare_ipc)

-- profiles

klipper_python2_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e;\
  [[ ! -d klipper_py2 ]] && git clone https://github.com/KevinOConnor/klipper.git klipper_py2;\
  (cd klipper_py2 && git reset --hard && git clean -dfx --force && git checkout master && git pull --force);\
  rm -rf klipper_env_py2;\
  virtualenv -p python2 klipper_env_py2;\
  klipper_env_py2/bin/pip install -r klipper_py2/scripts/klippy-requirements.txt;\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

-- experimental, may have some issues
klipper_python3_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e;\
  [[ ! -d klipper_py3 ]] && git clone https://github.com/Doridian/klipper.git klipper_py3;\
  (cd klipper_py3 && git reset --hard && git clean -dfx --force && git checkout custom && git pull --force);\
  rm -rf klipper_env_py3;\
  virtualenv -p python3 klipper_env_py3;\
  klipper_env_py3/bin/pip install -r klipper_py3/scripts/klippy-requirements.txt;\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

uartclient_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e;\
  [[ ! -d uartbridge ]] && git clone https://github.com/DarkCaster/ArduinoUARTEthernetBridge.git uartbridge;\
  (cd uartbridge && git reset --hard && git clean -dfx --force && git checkout main && git pull --force);\
  cd uartbridge/Client;\
  cmake .; make;\
  cd ~; rm -rf uartclient_bin; mkdir -p uartclient_bin;\
  mv uartbridge/Client/uartclient uartclient_bin;\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

-- experimental, may have some issues
klipper_python3={
  exec="/home/sandboxer/klipper_env_py3/bin/python3",
  path="/home/sandboxer/klipper_py3/klippy",
  args={"klippy.py", "-l", "/home/sandboxer/logs/klipper_py3.log", loader.path.combine("/home/sandboxer/configs",loader.args[1])},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

klipper_python2={
  exec="/home/sandboxer/klipper_env_py2/bin/python2",
  path="/home/sandboxer/klipper_py2/klippy",
  args={"klippy.py", "-l", "/home/sandboxer/logs/klipper_py2.log", loader.path.combine("/home/sandboxer/configs",loader.args[1])},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- run the whole suite and wait for ctrl+c, or termination signal:
-- 1. klipper firmware
-- 2. uart-ethernet-client for connecting to MCU uart port(s) via Ethernet/TCP (see https://github.com/DarkCaster/ArduinoUARTEthernetBridge)
-- 3. octo-pi software
klipper_suite={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","\
  klipper_pid=\"\";uartclient_pid=\"\";octopi_pid=\"\";\
  collect_logs(){ mv /tmp/klipper.log ~/logs/klipper.log; };\
  do_exit(){ ec=\"$1\"; [[ -z $ec ]] && ec=\"1\"; [[ $ec != 0 ]] && echo 'stopping with error!' || echo 'stopping'; trap - ERR INT TERM HUP; kill -SIGTERM $klipper_pid 2>/dev/null; kill -SIGTERM $uartclient_pid 2>/dev/null; kill -SIGTERM $octopi_pid 2>/dev/null; collect_logs; exit $ec; };\
  trap 'do_exit' ERR;\
  trap 'do_exit 0' INT TERM HUP;\
  cd ~/klipper_py2/klippy;\
  ~/klipper_env_py2/bin/python2 klippy.py -l /tmp/klipper.log \""..loader.path.combine("/home/sandboxer/configs",loader.args[1]).."\" &\
  klipper_pid=\"$!\";\
  ~/uartclient_bin/uartclient -nd 1 -ra ENC28J65E366.lan -rp1 50000 -rp2 50001 -rp3 50002 -lp1 /tmp/ttyETH1 -lp2 /tmp/ttyETH2 -lp3 /tmp/ttyETH3 -ps1 250000 -ps2 250000 -ps3 250000 -pm1 6 -pm2 6 -pm3 6 -rst1 0 -rst2 0 -rst3 0 &\
  uartclient_pid=\"$!\";\
  wait $klipper_pid; $uartclient_pid;\
  "},
  term_signal=defaults.signals.SIGHUP,
  attach=true,
  pty=true,
  exclusive=true,
  term_orphans=true,
}

-- display klipper log from container's tmpfs
klipper_log={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","cat /tmp/klipper.log"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=false,
}
