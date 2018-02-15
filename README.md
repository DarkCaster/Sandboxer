# Simple desktop application sandboxing tool for GNU/Linux

Main goal of this project is to make a simple to configure and yet highly customizable application sandboxing/isolation suite.
In addition to sandboxing feature, this suite can also be used to run applications inside pre-configured custom environment based on user-made chroot, in a similiar way to how it is done in a server containerization software like libvirt-lxc, LXC, docker, etc.

For now, this project is relying on "bubblewrap" utility (<https://github.com/projectatomic/bubblewrap>) to perform application isolation.
Authors of bwrap implemented only minimal and essential functionality in its sandboxing utility.
While it is good in terms of security, easy to maintain and fix bugs, it is also hard to configure and perform a preparation of sandboxed environment.
That where this sandboxer suite comes in.
It is just a configuration wrapper and set of service utilities that made on top of bubblewrap.

For now it is in highly experimental state and possibly not so secure that it is intended to be.
Do not rely on it to achive a 100% secutity with application isolation.
It is impossible to achive with LXC-like containerization that provided by bubblewrap utility and linux kernel namespaces.
Also, this software may contain some security bugs because I have a very limited time recources to maintain and enhance it and i'm the only one developer working on it right now.
Even more mature software like firejail contain bugs and security vulnerabilities that discovered on a regular basis.
So, proceed at your own risk.
If you need more secure isolation - use virtualization solutions like qemu-kvm, virtualbox, etc.
But, still, i'm trying to do my best to make this tool secure.

## Packages for ubuntu and debian distributions:

*   [Launchpad](https://launchpad.net/~dark-caster/+archive/ubuntu/sandboxer), for ubuntu distributions
*   [OBS](https://build.opensuse.org/repositories/home:Warhammer40k:sandboxer), for debian and ubuntu distributions

## Main concepts of this sandboxing suite:

There is an environment constructed by your OS, used in your normal user-session and DE.
It is called there - a host environment (or simply - "host").
Usually it does not have any tight security restrictions - applications may interact with each other and read/write user-data.
When you run malicious or broken app inside unprotected host env - it may damage, delete or steal your data and/or break other running applications.

Sandboxer suite run applications inside "sandbox".
Sanbox - is a special environment isolated from host that provide some security for host against unexpected behaviour of software running inside sandbox.
Single sandbox may run multiple applications and they may interact with each other, but not with the host apps and apps from other sandboxes.
In order to interact with sandboxed application, there must be some links that connect sandboxed application to services running on host - like X11 service, pulseaudio and stuff like that.
Sandboxer sute perform configuration of such links, optionally by use of some external software (for example: xpra <https://xpra.org>, to provide more secure X11 integration).

### Sandbox configuration management

Each sandbox environment must be setup by using it's configuration file.
Unique sandbox is usually bond to configuration file and it's on-disk location.
Sanboxer's configuration system uses lua language (<https://www.lua.org>) to manage config options.
Each config file is just a lua-script that must define global "tables" with config options.
This aproach was chosen because of it simplicity and extensibility.
Also, it was easier for me to program config options validation, and transformation - it is also written with lua language.

This aproach to sandbox configuration may change in future.
Core information about sandbox configuration options for now provided in example.cfg.lua example and others.
See example config files in "Examples" directory for more info.

Sandbox config file must define at least two root-tables:
*   "sandbox" table.
    It describes general sandbox env setup: mounts inside sandbox, persistent-user data location, isolation options, commands used at sandbox construction stage to prepare it's env.
*   One or more "execution profiles".
    Exec profile describe application that may be started inside sandbox by user.
    This may be an interactive shell, or some desktop application.
    All exec profiles described in a single config file - will be executed in a sanbox shared between them, so they may interact to each other.
    Exec profile also describe other options for target application, like working directory, cmd line parameters, pty allocation, logging of stdout/stderr, etc.

TODO: make more detailed howto about config files.

### Session management

Minimalistic bubblewrap utility can only launch a single application inside a dynamically constructed sandbox.
When controlled application (and it's childs) exit, then it's sandbox is destroyed.

In order to launch multiple applicaions inside bubblewrap-controlled sandbox, we need a session management utility.
It may be a ssh or telnet like utility, for example.
But it is too heavy and resource-hungry, and it lack some functionality required for us to control sandboxed application.

So, sandboxer suite comes with it's own session management utilities, that consists of two independend binaries.
"executor" binary is launched inside bubblewrap-controlled sandbox and perform all needed session management stuff and basic communication with outer world.
"commander" binary is launched inside host env and used in basic interactions with application that running inside sandbox.
It may forward or log stdio/stderr, securely forward terminal io from pty device created inside sandbox, it may be also used to ask session manager to terminate application or launch another one.

Session management utilities was written with native C language, to provide the best portability possible across different sandboxed environments.
Also this is the only utilities that may run all the time while controlled sandboxed application is executing, so it need not to consume much of system resources.
This utilities will be enforced in future with stuff like seccomp, refactored and optimized, or maybe even rewritten in more secure system programming language like Rust.
Sandboxer suite will handle this utilities internally, it is not intended for direct use - command line parameters and internal logic may change in future releases without any notice.

### Sandbox management and application starup

To construct a sandboxed environment, we need to perform some preparations like copying some configuration files from host /etc directory (so, sandboxed app will have access only to needed parts of system configs), define mounts for rootfs inside sandbox, define command line options for bubblewrap utility.

Such tasks executed on host system only at sandoxed application startup/shutdown by main sandboxer utility.
In order to accelerate project development, this utility and it's components written in Bash scripting laguage for now.
I'm trying to use only native bash features, and not to rely on other utilities in order to provode good portability across different systems.
Anyway, this utilities is intended to perform only initial coniguration tasks, and it should not affect performance or memory usage for sandboxed environment.
It may be also rewritten in future with other programming language.

#### Usage
```
sandboxer <sandbox config file> <exec profile> [parameters for application inside sandbox]
```
Execution must be performed from regular-user account.
Running from root is not supported and will be unsecure.
Bubblewrap utility is also intended to run as normal user.

TODO: detailed description, see "Examples" directory for config files examples.
Look for more info at "example.cfg.lua", "debian-setup.cfg.lua", "debian-sandbox.cfg.lua" and other example config files.

## System requirements and installation

In order to use sandboxer suite your system should meet a minimum system requirements to run a bubblewrap utility:
*   A decent linux kernel with various namespaces support: PID, UID, NET and IPC namespace support is highly recommended.

Sandboxer suite also requires the following in order to run:
*   A decent x86_64 linux distro.
    Sandboxer suite may work with 32bit x86 OS'es (and with non x86 systems), but it is not tested right now.
    Some modifications to config system (but not the user config files) and main logic may be required.
*   Official standalone lua interpreter (<https://www.lua.org>) to parse and transform config files and it's options.
    System is tested with lua versions 5.1, 5.2 and 5.3. Other lua implementations like lua-jit is not supported right now (but may be supported in future).
*   Bash version 4.0 and up.
    Required by components that perform sandbox preparation tasks.
*   Optional: posix compliant shell/interpreter (tested with bash, dash, busybox) to consume less system resources when running some components.
    This requirement is optional, bash will be used as fallback.
*   Optional: Xpra software (<https://xpra.org/>), version 2.0 and up.
    Both server and client components must be installed.
    If using sandbox based on exernal root-fs, then xpra server components must be installed there.
    May be used to perform secure X11 integration for sandboxed application.

In order to build and install sandboxer suite you also need:
*   Git VCS. It is required in order to download some external dependencies and extra utilities.
*   GCC compiler and CMAKE is required to build all internal binary components.
*   Autotools is required to build FakeRoot-UserNS external helper utility.

### Building/installing bubblewrap utility

Check your package manager, maybe bubblewrap utility is already available there.
It may be also included in "flatpak" package.

To build and install bubblewrap manually, run "build-bwrap.sh" script - it will download, compile and install bwrap binary to /usr/local, sudo will prompt for password at install stage, no need to run this script as root.

### Building sandboxer suite

Run build.sh script, it will download and build all external dependencies, build binary components.

### Installing sandboxer suite

Run install-to-home.sh, after build.sh script completed without errors.
It will install sandboxer suite and examples to "$HOME/sandboxer" directory, and make symlink to main utlilty at "$HOME/bin/sandboxer".
You may also pass custom target installation path to install-to-home.sh script as parameter.

## Project status

### Short term plans

*   Add tools for gathering statistics from running sandboxes
*   Improve logging from sandboxed applications
*   Add tools that will perform setup of custom network-namespace and firewalling for sandboxed application.
    For now it is only possible to run sandbox with host networking, or run sandbox with empty network-namespace without any external connectivity.
*   Improve session management utilities: use unix-sockets instead of pipes, add vsock support (for use with qemu guests), refactor and simplify code
*   Implement seccomp mechanisms to session management utilities, loading of seccomp rules for application executed inside sandbox.
*   Add different LXC backends support, virtualization backend support
*   Rewrite main management utilities-prototypes from bash to some other language to speedup sandbox preparation process.

### Long term plans

*   Test for selinux support, add helper tools for selinux setup to sandboxes based on external root-fs
*   Test for apparmor support as alternative, add some helper tools to generate apparmor rules for sandboxes
*   Add some restrictions for lua config files functionality if it is possible.
    For now when using lua interpreter, it is possible to use all functionality that lua can provide: including disk access and using external modules. There should be some limitations for portable sandbox config files for good.

Copyright (c) 2016-2017 DarkCaster, see LICENSE for details.
