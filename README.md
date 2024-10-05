# Application sandboxing tool for GNU/Linux

## Deprecation notice

This tool is no longer in active development due to time constraints. While maintenance will continue when possible, updates will be less frequent. I still using it for some daily tasks but cannot extensively test it across various Linux distributions. Package updates for different host Linux distributions have ceased, as this process relied heavily on the Travis service, which is no longer available. The only way to use the Sandboxer suite now is to build it manually from source.

Since its inception in 2012 and creation in 2016, the landscape of application isolation and containerization has evolved significantly, making it challenging to keep pace with these changes and compete with newer solutions.

The suite was originally designed to run outdated and customized development tools on modern Linux distributions more conveniently than using virtualization or simple chroot. Desktop application support was added later but was never fully optimized. It currently runs X11 apps relatively well (even with hardware acceleration) but lacks proper support for pure Wayland host sessions. Audio integration also still working with PulseAudio in sandbox and PulseAudio/Pipewire on host.

For those seeking alternatives:

- For desktop use, consider Flatpak, which offers a more robust and production-ready solution.
- For server use, options like Docker and various hosted web-app providers are now widely available.

It is recommended to explore these modern solutions before trying Sandboxer. However, if Sandboxer still meets your specific needs, you are welcome to use and contribute to it.

## Description

The main goal of this project is to create a customizable application sandboxing/isolation suite. In addition to sandboxing, this suite can also be used to run applications inside pre-configured custom environments based on user-made chroots, similar to server containerization software like libvirt-lxc, LXC, docker, etc.

This project relies on the "bubblewrap" utility (<https://github.com/projectatomic/bubblewrap>) to perform application isolation. The authors of bwrap implemented only minimal and essential functionality in their sandboxing utility. While this is good for security and ease of maintenance, it can be challenging to configure and prepare a sandboxed environment. That's where the sandboxer suite comes in. It is a configuration wrapper and set of service utilities built on top of bubblewrap.

This software may contain security bugs due to limited development resources. Use at your own risk. For more secure isolation, consider using virtualization solutions like qemu-kvm, virtualbox, etc.

## Main concepts of this sandboxing suite

The environment constructed by your OS and used in your normal user-session is called the host environment (or simply "host"). It typically doesn't have tight security restrictions, allowing applications to interact with each other and read/write user data. Running malicious or broken apps in an unprotected host environment may damage, delete, or steal your data and/or affect other running applications.

The Sandboxer suite runs applications inside a "sandbox" - a special environment isolated from the host that provides security against unexpected behavior of software running inside the sandbox. A single sandbox may run multiple applications that can interact with each other but not with host apps or apps from other sandboxes. To interact with sandboxed applications, there must be links connecting them to services running on the host, such as X11 service and PulseAudio. The Sandboxer suite configures and uses these links. So it is possible to seamlessly run desktop, 3D, multimedia or GPU-compute software inside sandbox.

### Sandbox configuration management

Each sandbox environment is set up using a configuration file. A unique sandbox is bound to a configuration file and its on-disk location. The Sandboxer's configuration system uses the Lua language (<https://www.lua.org>) to manage config options. Each config file is a Lua script that defines global "tables" with config options. This approach was chosen for its simplicity and extensibility, making it easier to program config options validation and transformation.

The sandbox config file must define at least two root-tables:

* "sandbox" table: Describes general sandbox env setup, including mounts inside the sandbox, persistent user data location, isolation options, and commands used at the sandbox construction stage.
* One or more "execution profiles": Describe applications that can be started inside the sandbox by the user, such as an interactive shell or desktop application. All exec profiles in a single config file will be executed in a sandbox shared between them, allowing interaction. Exec profiles also describe other options for the target application, like working directory, command-line parameters, pty allocation, and logging of stdout/stderr.

### Session management

To launch multiple applications inside a bubblewrap-controlled sandbox, the Sandboxer suite includes its own session management utilities:

* "executor" binary: Launched inside the bubblewrap-controlled sandbox to perform session management and basic communication with the outer world.
* "commander" binary: Launched in the host environment for basic interactions with applications running inside the sandbox. It can forward or log stdio/stderr, securely forward terminal I/O from pty devices created inside the sandbox, and ask the session manager to terminate or launch applications.

These utilities are written in C for optimal portability and resource efficiency. They are not intended for direct use, as command-line parameters and internal logic may change in future releases without notice.

### Sandbox management and application startup

The main sandboxer utility performs preparation tasks on the host system at sandboxed application startup/shutdown. These tasks include copying configuration files, defining mounts for rootfs inside the sandbox, and setting command-line options for bubblewrap. The utility and its components are currently written in Bash scripting language for rapid development, aiming to use native Bash features for portability across different systems.

#### Usage

```sh
sandboxer <sandbox config file> <exec profile> [parameters for application inside sandbox]
```

Execution must be performed from a regular user account. Running from root is not supported and would be insecure.

##### Example: Prepare and run sandbox on top of separate Ubuntu rootfs

1. Create a separate directory to store files for Ubuntu rootfs.
2. Copy or create symlinks to the following files from the "Examples" directory: debian-setup.cfg.lua, debian-sandbox.cfg.lua, debian-version-probe.lua.in, download-ubuntu-chroot.sh, debian-minimal-setup.sh.
3. Download and install Ubuntu rootfs by running: `./download-ubuntu-chroot.sh 24.04` (run as regular user, DO NOT run this as root!)
4. Run the "setup" sandbox: `sandboxer debian-setup.cfg.lua fakeroot_shell`
5. Install essential packages by running `/root/debian-minimal-setup.sh` inside the sandbox shell.
6. Logout by calling "exit".
7. Run the regular sandbox: `sandboxer debian-sandbox.cfg.lua shell`

## System requirements and installation

The Sandboxer suite requires:

* x86_64 Linux distribution (may work with 32-bit x86 OS and non-x86 systems, but untested)
* bubblewrap (`bwrap`) utility
* For AppArmor-enabled systems: manual installation of extra AppArmor rules for bwrap (use the provided `bwrap-apparmor-rule` example)
* Official standalone Lua interpreter (versions 5.1, 5.2, 5.3, and 5.4 supported)
* Bash version 4.0 and up
* Optional: POSIX-compliant shell/interpreter (tested with bash, dash) for reduced resource consumption

For building and installing:

* Git VCS
* GCC compiler and CMake
* Autotools (for building FakeRoot-UserNS external helper utility)

### Building/installing bubblewrap utility

Use your package manager if bubblewrap is available. To build and install manually, run the "build-bwrap.sh" script.

### Building sandboxer suite

Run the build.sh script to download and build all external dependencies and binary components.

### Installing sandboxer suite

Run install-to-home.sh after build.sh completes successfully. It will install the sandboxer suite and examples to "$HOME/sandboxer" and create a symlink to the main utility at "$HOME/bin/sandboxer". You can pass a custom target installation path as a parameter.

### Downloading precompiled binaries (optional)

The sandboxer-download-extra.sh utility is used to download precompiled binaries for running in sandboxes with older or newer Linux distributions. Host-compiled versions of these utilities may be incompatible with sandboxed Linux distributions of different versions (especially older ones). This utility checks, downloads, and verifies precompiled helper utilities for use with different types of external root-fs sandboxes.

To use the utility, run:

```sh
sandboxer-download-extra.sh [space separated targets list]
```

If no targets are specified, it will download binaries for debian-i386, debian-amd64, and ubuntu-amd64 by default. The downloaded components will be placed in ~/.cache/sandboxer, which can be removed if no longer needed.

## Project status

### Long term plans

* Add host<->sandbox path conversion tools for better integration into the host system.
* Create an xdg-open wrapper for improved integration, allowing the sandbox to execute xdg-open with files/protocols from the sandbox in the host system.

### Very long term plans (potentially)

* Improve session management utilities: use unix-sockets instead of pipes, add vsock support (for use with QEMU guests), refactor and simplify code.

Copyright (c) 2016-2024 DarkCaster, see LICENSE for details.