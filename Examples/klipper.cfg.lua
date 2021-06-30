-- config for running klipper 3D printer suite on local (desktop) machine.
-- i'm using this to simplify debugging of modifications to the klipper source code for my hobby project.
-- any prodction use of tools/configuration/setup provided here was not tested and cannot be guaranteed.

-- packages need to be installed:
-- libsodium-dev
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
table.insert(sandbox.setup.mounts,{prio=99,"bind",loader.path.combine(loader.workdir,"gcode"),"/home/sandboxer/gcode"})
table.insert(sandbox.setup.mounts,{prio=99,"bind",loader.path.combine(loader.workdir,"configs"),"/home/sandboxer/configs"})
table.insert(sandbox.setup.mounts,{prio=99,"bind",loader.path.combine(loader.workdir,"logs"),"/home/sandboxer/logs"})

-- add bwrap unshare_ipc option
loader.table.remove_value(sandbox.bwrap,defaults.bwrap.unshare_ipc)
table.insert(sandbox.bwrap,defaults.bwrap.unshare_ipc)

-- profiles for installing all needed stuff individually

-- forward UART port from target MCUs over Ethernet/TCP-IP
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

-- component needed for klipper web-ui
-- TODO: create moonraker.conf with config sutable for this env, if missing
moonraker_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e;\
  [[ ! -d moonraker ]] && git clone https://github.com/Arksine/moonraker.git moonraker;\
  (cd moonraker && git reset --hard && git clean -dfx --force && git checkout master && git pull --force);\
  rm -rf moonraker_env;\
  virtualenv -p python3 moonraker_env;\
  moonraker_env/bin/pip install -r moonraker/scripts/moonraker-requirements.txt;\
  [[ ! -f /home/sandboxer/configs/moonraker.conf ]] && echo \"installing sample config file\" && (cd /home/sandboxer/configs && wget \"https://raw.githubusercontent.com/Arksine/moonraker/master/docs/moonraker.conf\");\
  true;\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

-- web UI
fluidd_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e;\
  rm -rf fluidd;\
  mkdir fluidd;\
  cd fluidd;\
  wget -O fluidd.zip \"https://github.com/cadriel/fluidd/releases/latest/download/fluidd.zip\";\
  unzip fluidd.zip;\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

klipper_install={
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

-- avr-gcc and avrdude from arduino distribution for building firmware for my MCUs
avr_gcc_install={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","set -e;\
  rm -rf avr;\
  rm -rf avrdude;\
  rm -fv avr-gcc.tar.bz2;\
  rm -fv avrdude.tar.bz2;\
  wget -O avr-gcc.tar.bz2 \"http://downloads.arduino.cc/tools/avr-gcc-7.3.0-atmel3.6.1-arduino7-x86_64-pc-linux-gnu.tar.bz2\";\
  wget -O avrdude.tar.bz2 \"http://downloads.arduino.cc/tools/avrdude-6.3.0-arduino18-x86_64-pc-linux-gnu.tar.bz2\";\
  bzip2 -d -c avr-gcc.tar.bz2 | tar xf - ;\
  bzip2 -d -c avrdude.tar.bz2 | tar xf - ;\
  rm -v avr-gcc.tar.bz2;\
  rm -v avrdude.tar.bz2;\
  [[ ! -d avr ]] && echo \"cannot find extracted 'avr' directory!\" && exit 1 || true;\
  [[ ! -d avrdude ]] && echo \"cannot find extracted 'avrdude' directory!\" && exit 1 || true;\
  "},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}

-- run make in klipper source directory
-- invocation example: sandboxer klipper.cfg.lua klipper_make menuconfig
klipper_make={
  exec="/usr/bin/make",
  path="/home/sandboxer/klipper_py2",
  args=loader.args,
  env_unset={"PATH","LANG"},
  env_set={
    {"PATH","/home/sandboxer/avr/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"},
    {"TERM",os.getenv("TERM")},
  },
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- uartclient configured for flashing image via optiboot/uart
uartclient={
  exec="/home/sandboxer/uartclient_bin/uartclient",
  path="/home/sandboxer",
  args={"-nd","1","-ra","ENC28J65E366.lan","-rp1","50000","-rp2","50001","-rp3","50002","-lp1","/tmp/ttyETH1","-lp2","/tmp/ttyETH2","-lp3","/tmp/ttyETH3","-ps1","115200","-ps2","115200","-ps3","115200","-pm1","6","-pm2","6","-pm3","6","-rst1","1","-rst2","1","-rst3","1"},
  env_unset={"LANG"},
  env_set={{"TERM",os.getenv("TERM")}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- example for flashing image to AVR MCU with optiboot bootloader:
-- sandboxer klipper.cfg.lua avrdude -P/tmp/ttyETH3 -b115200 -carduino -patmega328p -v -D -Uflash:w:klipper.elf.hex:i
avrdude={
  exec="/home/sandboxer/avrdude/bin/avrdude",
  path="/home/sandboxer",
  args={"-C/home/sandboxer/avrdude/etc/avrdude.conf", table.unpack(loader.args)},
  env_unset={"LANG"},
  env_set={{"TERM",os.getenv("TERM")}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- start klipper, provide config file-name placed into "configs" directory as parameter
klipper={
  exec="/home/sandboxer/klipper_env_py2/bin/python2",
  path="/home/sandboxer/klipper_py2/klippy",
  args={"klippy.py", "-l", "/home/sandboxer/logs/klipper.log", loader.path.combine("/home/sandboxer/configs",loader.args[1])},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- run the whole suite and wait for ctrl+c, or termination signal:
-- 1. klipper firmware
-- 2. uart-ethernet-client for connecting to MCU uart port(s) via Ethernet/TCP-IP (see https://github.com/DarkCaster/ArduinoUARTEthernetBridge)
-- 3. moonraker server and fluidd for web UI
klipper_suite={
  exec="/bin/bash",
  path="/home/sandboxer",
  args={"-c","\
  klipper_pid=\"\"; uartclient_pid=\"\"; moonraker_pid=\"\";\
  collect_logs() { local d=$(date +\"%Y.%m.%d.%H%M.%S\"); cp /tmp/klipper.log ~/logs/klipper.$d.log; };\
  do_exit() { ec=\"$1\"; [[ -z $ec ]] && ec=\"1\"; [[ $ec != 0 ]] && echo 'stopping with error!' || echo 'stopping'; trap - ERR INT TERM HUP; kill -SIGTERM $klipper_pid 2>/dev/null; kill -SIGTERM $uartclient_pid 2>/dev/null; kill -SIGTERM $moonraker_pid 2>/dev/null; kill -SIGTERM $fluidd_pid 2>/dev/null; collect_logs; exit $ec; };\
  trap 'do_exit' ERR;\
  trap 'do_exit 0' INT TERM HUP;\
  ~/uartclient_bin/uartclient -fc 1 -nd 0 -ra ENC28J65E366.lan -rp1 50000 -rp2 50001 -rp3 50002 -lp1 /tmp/ttyETH1 -lp2 /tmp/ttyETH2 -lp3 /tmp/ttyETH3 -ps1 250000 -ps2 250000 -ps3 250000 -pm1 6 -pm2 6 -pm3 6 -rst1 1 -rst2 1 -rst3 1 &\
  uartclient_pid=\"$!\";\
  rm -rf /tmp/klipper.log;\
  cd ~/klipper_py2/klippy;\
  ~/klipper_env_py2/bin/python2 klippy.py -a /tmp/klippy_uds -l /tmp/klipper.log \""..loader.path.combine("/home/sandboxer/configs",loader.args[1]).."\" &\
  klipper_pid=\"$!\";\
  cd ~/moonraker;\
  ~/moonraker_env/bin/python3 moonraker/moonraker.py -c /home/sandboxer/configs/moonraker.conf &>/tmp/moonraker.out.log &\
  moonraker_pid=\"$!\";\
  cd ~/fluidd;\
  python3 -m http.server 8080 --bind 127.0.0.1 &>/tmp/fluidd.out.log &\
  fluidd_pid=\"$!\";\
  wait $uartclient_pid;\
  wait $klipper_pid;\
  wait $moonraker_pid;\
  wait $fluidd_pid;\
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

-- experimental python3 klipper-build, may have some issues
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

klipper_python3={
  exec="/home/sandboxer/klipper_env_py3/bin/python3",
  path="/home/sandboxer/klipper_py3/klippy",
  args={"klippy.py", "-l", "/home/sandboxer/logs/klipper_py3.log", loader.path.combine("/home/sandboxer/configs",loader.args[1])},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}
