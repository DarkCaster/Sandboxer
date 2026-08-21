defaults.recalculate_orig=defaults.recalculate

function defaults.recalculate()
  tunables.user="ds"
  tunables.datadir=loader.path.combine(loader.workdir,"userdata-ds")
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
table.insert(sandbox.setup.env_set,{{"GOROOT","/home/ds/go_dist"},{"PATH","/home/ds/go_dist/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"}})
-- table.insert(sandbox.setup.env_set,{"CHROME_EXECUTABLE","/usr/bin/microsoft-edge"})

-- add mount for the ~/installs dir if present
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind-try",loader.path.combine(loader.workdir,"installs"),"/home/ds/installs"})

--sandbox.bwrap_cmd={
--  "netns-runner.sh",
--  "vde_air2",
--  "bwrap"
--}

shell.env_unset={"MAIL"}
shell.env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}}
-- shell.path="/home/ds/projects"

-- you may need to install fd-find and ripgrep packages into sandbox manaully

-- install this if need to install node
nvm_curl_install={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic", "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- remove nvm + node + node_modules (including dhs), leave dhs configuration intact
node_cleanup={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic",
    "echo removing .npm && rm -rf ~/.npm; "..
    "echo removing .nvm && rm -rf ~/.nvm; "..
    "echo removing node_modules && rm -rf ~/node_modules; "..
    "echo removing package info && rm -f ~/package-lock.json && rm -f ~/package.json",
  },
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- install this to install node
node24_nvm_install={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic", "nvm install 24"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

node26_nvm_install={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic", "nvm install 26"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

ds_npm_install={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic",
    "echo updating npm && npm install -g npm@latest && "..
    "echo installing ds && npm cache clean --force && "..
    "npm install @deepseek-ai/dsh@latest"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"},{"NODE_OPTIONS","--max-old-space-size=4096"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- run web agent
ds_web={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic", "npx @deepseek-ai/dsh --profile web --port 3080 --host 127.0.0.1 --no-open"},
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
  term_orphans=true,
}

-- external tools and SDKs
go_install={
  exec="/bin/bash",
  path="/tmp",
  args={"-c","rm -rf $HOME/go_dist && img=`find $HOME/installs -name \"go*linux-amd64.tar.gz\"|sort|tail -n1` && ( gunzip -c \"$img\" | tar xf - ) && mv /tmp/go $HOME/go_dist"},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=false,
  exclusive=true,
}
