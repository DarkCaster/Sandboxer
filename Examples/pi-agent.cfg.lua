defaults.recalculate_orig=defaults.recalculate

function defaults.recalculate()
  tunables.user="pi"
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-pi")
  -- tmp directory for /tmp mount, tmpfs may be too small sometimes
  -- tunables.custom_tmp_path=loader.path.combine(tunables.datadir,"root_tmp")
  defaults.recalculate_orig()

  tunables.features.x11host_target_dir="/dev/null"
  defaults.mounts.resolvconf_mount=defaults.mounts.direct_resolvconf_mount
  defaults.mounts.hosts_mount=defaults.mounts.direct_hosts_mount
  defaults.mounts.hostname_mount=defaults.mounts.direct_hostname_mount
end

defaults.recalculate()

-- load base config
dofile(loader.path.combine(loader.workdir,"debian-sandbox.cfg.lua"))

-- remove some unneded features and mounts
loader.table.remove_value(sandbox.features,"pulse")
loader.table.remove_value(sandbox.features,"dbus")

-- remove some mounts from base config

-- NOTE: /sys mount is needed for adb\fastboot to work, so comment next line if working with adb
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.sys_mount)

loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devsnd_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devinput_mount)

loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devdri_mount)
loader.table.remove_value(sandbox.setup.mounts,defaults.mounts.devshm_mount)

-- set hostname to "sandbox"
table.insert(sandbox.bwrap,defaults.bwrap.hostname_sandbox)

-- modify env
table.insert(sandbox.setup.env_set,{"PATH","/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"})
-- table.insert(sandbox.setup.env_set,{"CHROME_EXECUTABLE","/usr/bin/microsoft-edge"})

-- add mount for the ~/installs dir if present
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind-try",loader.path.combine(loader.workdir,"installs"),"/home/pi/installs"})

--sandbox.bwrap_cmd={
--  "netns-runner.sh",
--  "vde_air2",
--  "bwrap"
--}

shell.term_orphans=true
shell.env_unset={"MAIL"}
shell.env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}}

nvm_curl_install={
  exec="/bin/bash",
  path="/home/pi",
  args={"-lic", "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

node24_nvm_install={
  exec="/bin/bash",
  path="/home/pi",
  args={"-lic", "nvm install 24"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

pi_npm_install={
  exec="/bin/bash",
  path="/home/pi",
  args={"-lic", "echo \"updating npm\" && npm install -g npm@latest && echo \"updating packages\" && npm update -g && echo \"installing pi\" && npm install -g --ignore-scripts @earendil-works/pi-coding-agent"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

pi_curl_install={
  exec="/bin/bash",
  path="/home/pi",
  args={"-lic", "curl -fsSL https://pi.dev/install.sh | sh"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- may need to install fd-find and ripgrep packages
pi={
  exec="/bin/bash",
  path="/home/pi",
  args={"-lic", "pi && clear"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
  term_orphans=true,
}

pi_resume={
  exec="/bin/bash",
  path="/home/pi",
  args={"-lic", "pi -r && clear"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
  term_orphans=true,
}
