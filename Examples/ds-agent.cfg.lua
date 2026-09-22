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
table.insert(sandbox.setup.env_set,{{"GOROOT","/home/ds/go_dist"},{"PATH","/home/ds/node_modules/.bin:/home/ds/go_dist/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"}})
-- table.insert(sandbox.setup.env_set,{"CHROME_EXECUTABLE","/usr/bin/microsoft-edge"})

-- add mount for the ~/installs dir if present
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind-try",loader.path.combine(loader.workdir,"installs"),"/home/ds/installs"})
table.insert(sandbox.setup.mounts,{prio=99,"ro-bind-try","/mnt/data/Sources/DeepSeek-Harness","/home/ds/ds_dist"})

--sandbox.bwrap_cmd={
--  "netns-runner.sh",
--  "vde_air2",
--  "bwrap"
--}

shell.env_unset={"MAIL"}
shell.env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}}

-- remove nvm + node + node_modules, dhs (both from npm and git), leave dhs configuration intact
cleanup={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic",
    "echo removing .npm && rm -rf ~/.npm; "..
    "echo removing .nvm && rm -rf ~/.nvm; "..
    "echo removing node_modules && rm -rf ~/node_modules; "..
    "echo removing .node_modules && rm -rf ~/.node_modules; "..
    "echo removing package info && rm -f ~/package-lock.json && rm -f ~/package.json; "..
    "echo removing .cache/pnpm && rm -rf ~/.cache/pnpm; "..
    "echo removing .local/share/pnpm && rm -rf ~/.local/share/pnpm; "..
    "echo removing .local/state/pnpm && rm -rf ~/.local/state/pnpm; "..
    "echo removing .dsh-src && rm -rf ~/.dsh-src; "..
    "echo removing .dsh/profiles/node_modules && rm -rf ~/.dsh/profiles/node_modules; "..
    "echo removing .dsh/profiles/web/node_modules && rm -rf ~/.dsh/profiles/web/node_modules; "..
    "echo removing .dsh/profiles/web/.dsh-module-fallback && rm -rf ~/.dsh/profiles/web/.dsh-module-fallback; "
  },
  env_unset={"MAIL"},
  env_set={{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

-- install this to install node
node26_nvm_install={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic",
  "(curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash) && "..
  "export NVM_DIR=$HOME/.nvm && . $NVM_DIR/nvm.sh && "..
  "nvm install 26 && echo updating npm && npm install -g npm@latest && echo installing pnpm && npm install -g get-pnpm@latest && npx get-pnpm next-12"},
  env_unset={"MAIL"},
  env_set={{"SHELL","/bin/bash"},{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"},{"NODE_OPTIONS","--max-old-space-size=3072"}},
  term_signal=defaults.signals.SIGTERM,
  attach=true,
  pty=true,
  exclusive=true,
}

ds_git_install={
  exec="/bin/bash",
  path="/home/ds",
  args={"-lic",
    "echo installing ds && mkdir -p .dsh-src/src && git clone --depth 1 file:///home/ds/ds_dist/Tiny-DSH .dsh-src/src; "..
    "echo cleaning-up old node_modules && rm -rf ~/node_modules; "..
    "cd .dsh-src/src; "..
    -- "echo resetting git commit && git reset --hard 76fda729799fe9b3848dbe2c211d4b231032b81e && "..
    "echo resetting git repo && git clean -dfx --force && git reset --hard && "..
    "pnpm config set --location=project modulesDir $HOME/.dsh-src/node_modules && "..
    "pnpm config set --location=project packageImportMethod copy && "..
    "pnpm config set --location=project nodeLinker hoisted && "..
    "pnpm config set --location=project shamefullyHoist true && "..
    "echo creating node_modules src symlink && ln -s $HOME/.dsh-src/node_modules node_modules && "..
    "echo pnpm install && pnpm install && echo pnpm build && pnpm run build && "..
    "echo cleaning-up && rm -rf $HOME/.local/share/pnpm && rm -rf $HOME/.local/state/pnpm && rm -rf $HOME/.cache/pnpm && "..
    "echo creating node_modules home symlink && ln -s $HOME/.dsh-src/node_modules $HOME/node_modules",
  },
  env_unset={"MAIL"},
  env_set={{"SHELL","/bin/bash"},{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"},{"NODE_OPTIONS","--max-old-space-size=3072"},{"DSH_TELEMETRY_DISABLED","1"}},
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
  env_set={{"SHELL","/bin/bash"},{"TERM",os.getenv("TERM")},{"LANG","en_US.UTF-8"},{"LC_ALL","en_US.UTF-8"},{"TZ","GMT+0"},{"NODE_OPTIONS","--max-old-space-size=3072"},{"DSH_TELEMETRY_DISABLED","1"}},
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
