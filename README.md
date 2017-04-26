# Simple desktop application sandboxing tool for GNU/Linux

Main goal of this project is to make a simple to configure and yet highly customizable application sandboxing/isolation suite.
In addition to sandboxing feature, this suite can also be used to run applications inside pre-configured custom environment based on user-made chroot, in a similiar way to how it is done in a server containerization software like libvirt-lxc, LXC, docker, etc.

For now, this project is relying on bubblewrap utility (<https://github.com/projectatomic/bubblewrap>) to perform application isolation.
Authors of bwrap implemented only minimal and essential functionality in its sandboxing utility. While it is good in terms of security, easy to maintain and fix bugs, it is also hard to configure and perform a preparation of sandboxed environment. That where this sandboxer suite comes in. It is just a configuration wrapper and set of service utilities that made on top of bubblewrap.

For now it is in highly experimental state and possibly not so secure that it is intended to be. Do not rely on it to achive a 100% secutity with application isolation. It is impossible to achive with LXC-like containerization. Also, this software may contain some security bugs because I have a very limited time recources to maintain and enhance it and i'm the only one author right now. Even more mature software like firejail contain bugs and security vulnerabilities that discovered on a regular basis. So, proceed at your own risk. If you need more secure isolation - use virtualization solutions like qemu-kvm, virtualbox, etc. But, still, i'm trying to do my best to make this tool secure.

## Main concepts of this sandboxing suite:

There is an environment constructed by your OS, used in your normal user-session and DE. It is called there - a host environment (or simply - "host"). Usually it does not have any tight security restrictions - applications may interact with each other and read/write user-data. When you run malicious or broken app inside unprotected host env - it may damage, delete or steal your data and/or break other running applications.

Sandboxer suite run applications inside "sandbox". Sanbox - is a special environment isolated from host that provide some security for host against unexpected behaviour of software running inside sandbox. Single sandbox may run multiple applications and they may interact with each other, but not with the host apps and apps from other sandboxes. In order to interact with sandboxed application, there must be some links that connect sandboxed application to services running on host - like X11 service, pulseaudio and stuff like that. Sandboxer sute perform configuration of such links, optionally by use of some external software (for example: xpra <https://xpra.org>, to provide more secure X11 integration).

### Sandbox configuration management

Each sandbox environment must be setup by using it's configuration file.
Unique sandbox is usually bond to configuration file and it's on-disk location.
Sanboxer's configuration system uses lua language (<https://www.lua.org/>) to manage config options.
Each config file is just a lua-script that must define global "tables" with config options.
This aproach was chosen because of it simplicity and extensibility.
Also, it was easier for me to program config options validation, and transformation - it is also written with lua language.

This aproach to sandbox configuration may change in future.
See example config files in "Examples" directory for more info.
Core information about sandbox configuration presented in example.cfg.lua example and others.

Config files must define at least two root-tables:
*   "sandbox" table. It describes general sandbox env setup: mounts inside sandbox, persistent-user data location, isolation options, commands used at sandbox construction stage to prepare it's env.
*   One or more "execution profiles". Exec profile describe application that may be started inside sandbox by user. This may be an interactive shell, or some desktop application. All exec profiles described in a single config file - will be executed in a sanbox shared between them, so they may interact to each other. Exec profile also describe other options for target application, like working path, cmd line parameters, pty allocation, logging of stdout/stderr, etc.

TODO: make more detailed howto about config files.

Copyright (c) 2016-2017 DarkCaster, see LICENSE for details.
