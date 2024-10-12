JuNest
======

> [!IMPORTANT]
> Starting from Ubuntu 23.10+, [unprivileged user namespaces has been restricted](https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces).
> If using JuNest within Ubuntu, you may need root privileges in order to enable it.
> Alternatively, you can access JuNest using the `proot` mode as described
> [below](#Proot-based).

The lightweight Arch Linux based distro that runs, without root privileges, on top of any other Linux distro.

<h1 align="center">
    <a href="https://github.com/fsquillace/junest"><img
        alt="JuNest"
        width=250px
        src="https://cdn.rawgit.com/fsquillace/junest-logo/master/junest.svg"></a>
</h1>

|Project Status|Donation|Communication|
|:------------:|:------:|:-----------:|
| [![Build status](https://api.travis-ci.com/fsquillace/junest.png?branch=master)](https://app.travis-ci.com/github/fsquillace/junest) [![OpenHub](https://www.openhub.net/p/junest/widgets/project_thin_badge.gif)](https://www.openhub.net/p/junest) | [![Github Sponsors](https://img.shields.io/badge/GitHub-Sponsors-orange.svg)](https://github.com/sponsors/fsquillace) [![PayPal](https://img.shields.io/badge/PayPal-Donation-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=8LEHQKBCYTACY) [![Buy me a coffee](https://www.buymeacoffee.com/assets/img/custom_images/yellow_img.png)](https://www.buymeacoffee.com/fsquillace) | [![Join the Discord server at https://discord.gg/ttfBT7MKve](https://img.shields.io/badge/Discord-Server-blueviolet.svg)](https://discord.gg/ttfBT7MKve) |

**Table of Contents**
- [Description](#description)
- [Quickstart](#quickstart)
- [Installation](#installation)
- [Usage](#usage)
- [Advanced usage](#advanced-usage)
- [Internals](#internals)
- [Troubleshooting](#troubleshooting)
- [More documentation](#more-documentation)
- [Contributing](#contributing)
- [Donating](#donating)
- [Authors](#authors)

Description
===========
**JuNest** (Jailed User Nest) is a lightweight Arch Linux based distribution
that allows the creation of disposable and partially isolated GNU/Linux environments
within any generic GNU/Linux host OS and without requiring root
privileges to install packages.

JuNest is built around [pacman](https://wiki.archlinux.org/index.php/Pacman),
the Arch Linux package manager, which allows access
to a wide range of packages from the Arch Linux repositories.

The main advantages of using JuNest include:

- Install packages without root privileges.
- Create partially isolated environments in which you can install packages without risking mishaps on production systems.
- Access a wider range of packages, particularly on GNU/Linux distros with comparatively limited repositories (such as CentOS and Red Hat).
- Run on a different architecture from the host OS via QEMU.
- Available for `x86_64` and `arm` architectures but you can build your own image from scratch too!
- All Arch Linux lovers can enjoy their favourite distro everywhere!

JuNest follows the [Arch Linux philosophy](https://wiki.archlinux.org/index.php/The_Arch_Way).

How different is JuNest from Docker and Vagrant?
------------------------------------------------
Although JuNest sounds similar to a virtualisation/Linux container-like system,
JuNest is quite different from solutions like Docker or Vagrant.
In fact, the purpose of JuNest is **not** to
build a completely isolated environment but, conversely, to provide the ability to run
programs as if they were running natively from the host OS. Almost everything is shared
between the host OS and the JuNest sandbox (kernel, process subtree, network, mounting, etc)
and only the root filesystem gets isolated
(since the programs installed in JuNest need to reside elsewhere).

This allows interaction between processes belonging to both host OS and JuNest.
For example, you can install the `top` command in JuNest and use it to monitor
processes belonging to the host OS.

Installation
============

## Dependencies ##
JuNest comes with a very short list of dependencies in order to be installed in most
of GNU/Linux distributions.
Before installing JuNest be sure that all dependencies are properly installed in your system:

- [bash (>=4.0)](https://www.gnu.org/software/bash/)
- [GNU coreutils](https://www.gnu.org/software/coreutils/)

## Installation from git repository ##
Just clone the JuNest repo somewhere (for example in ~/.local/share/junest):

```sh
git clone https://github.com/fsquillace/junest.git ~/.local/share/junest
export PATH=~/.local/share/junest/bin:$PATH
```

Optionally you want to use the wrappers to run commands
installed in JuNest directly from host:

```sh
export PATH="$PATH:~/.junest/usr/bin_wrappers"
```
Update your `~/.bashrc` or `~/.zshrc` to get always the wrappers available.

### Installation using AUR (Arch Linux only) ###
If you are using an Arch Linux system you can, alternatively, install JuNest from the [AUR repository](https://aur.archlinux.org/packages/junest-git/).
JuNest will be located in `/opt/junest/`

Quickstart
==========

Setup environment
-----------------

The first operation required is to install the JuNest environment in the
location of your choice via `JUNEST_HOME` environment variable
(it must contain an absolute path) which by
default is `~/.junest`:

```sh
junest setup
```

The script will download the image from the repository and will place it to the default directory `~/.junest`.

Access to environment
---------------------

JuNest uses the Linux namespaces (aka `ns`) as the default backend program. To access via `ns` just type:

```sh
junest
```

You can use the command `sudo` to acquire fakeroot privileges and
install/remove packages.

Alternatively, you can access fakeroot privileges without using `sudo` all the
time with the `-f` (or `--fakeroot`) option:

```sh
junest -f
```

Another execution mode is via [Proot](https://wiki.archlinux.org/index.php/Proot):

```sh
junest proot [-f]
```

There are multiple backend programs, each with its own pros/cons.
To know more about the JuNest execution modes depending on the backend program
used, see the [Usage](#usage) section below.

Run JuNest installed programs directly from host OS
---------------------------------------

Programs installed within JuNest can be accessible directly from host machine
without entering into a JuNest session
(namely, no need to call `junest` command first).
For instance, supposing the host OS is an Ubuntu distro you can directly
run `pacman` by simply updating the `PATH` variable:

```sh
export PATH="$PATH:~/.junest/usr/bin_wrappers"
sudoj pacman -S htop
htop
```

By default the wrappers use `ns` mode. To use the `ns --fakeroot` you can use the convenient command helper `sudoj`.
For more control on backend modes you can use the `JUNEST_ARGS` environment variable too.
For instance, if you want to run `iftop` with real root privileges:

```
sudoj pacman -S iftop
sudo JUNEST_ARGS="groot" iftop
```

Bin wrappers can be always recreated (e.g. in case for some reasons they get
corrupted) with:

```
junest create-bin-wrappers -f
```

Bin wrappers are automatically generated each time they get installed inside JuNest.
This only works for executables located in `/usr/bin` path.
For executables in other locations (say `/usr/mybinpath`) you can only create
wrappers manually by executing the command:

```
junest create-bin-wrappers --bin-path /usr/mybinpath
```

Obviously, to get access to the corresponding bin wrappers you will need to
update your `PATH` variable accordingly:

```
export PATH="$PATH:~/.junest/usr/mybinpath_wrappers"
```

Install packages from AUR
-------------------------

In `ns` mode, you can easily install package from [AUR](https://aur.archlinux.org/) repository
using the already available [`yay`](https://aur.archlinux.org/packages/yay/)
command. In `proot` mode, JuNest does no longer support the building of AUR packages.

**Remember** that in order to build packages from AUR, `base-devel` package group is required
first:

```sh
pacman -S base-devel
```

JuNest uses a modified version of `sudo` provided by `junest/sudo-fake`. And the original `core/sudo`
package will be ignored **(and must not be installed)** during the installation of `base-devel`.

Have fun!
---------

If you are new on Arch Linux and you are not familiar with `pacman` package manager
visit the [pacman rosetta page](https://wiki.archlinux.org/index.php/Pacman_Rosetta).

Usage
=====
There are three different ways you can run JuNest depending on the backend program you decide to use.

Linux namespaces based
----------------------
The [Linux namespaces](http://man7.org/linux/man-pages/man7/namespaces.7.html)
represents the default backend program for JuNest.
The requirements for having Linux namespaces working are:

1. Kernel starting from Linux 3.8 allows unprivileged processes to create
user and mount namespaces.
1. The Linux kernel distro must have the user namespace enabled.

In the last years, the majority of GNU/Linux distros have the user namespace
enabled by default. This means that you do not need to have root privileges to
access to the JuNest environment via this method.
This
[wiki](https://github.com/fsquillace/junest/wiki/Linux-distros-with-user-namespace-enabled-by-default)
provides the state of the user namespace on several GNU/Linux distros.

In order to run JuNest via Linux namespaces:

- As normal user - Allow to make basic operations or install/remove packages
with `sudo` command: `junest ns` or `junest`
- As fakeroot - Allow to install/remove packages: `junest ns -f` or `junest -f`

This mode is based on the fantastic
[`bubblewrap`](https://github.com/containers/bubblewrap) command.

PRoot based
-----------
[Proot](https://wiki.archlinux.org/index.php/Proot) represents a portable
solution which allows unprivileged users to execute programs inside a sandbox
and works well in most of GNU/Linux distros available.

In order to run JuNest via Proot:

- As normal user - Allow to make basic operations: `junest proot`

- As fakeroot - Allow to install/remove packages: `junest proot -f`

In `proot` mode, the minimum recommended Linux kernel for the host OS is 2.6.32 on x86 (64 bit)
and ARM architectures. It is still possible to run JuNest on lower
2.6.x host OS kernels but errors may appear, and some applications may
crash. For further information, read the [Troubleshooting](#troubleshooting)
section below.

Chroot based
------------
This solution suits only for privileged users. JuNest provides the possibility
to run the environment via `chroot` program.
In particular, it uses a special program called `GRoot`, a small and portable
version of
[arch-chroot](https://wiki.archlinux.org/index.php/Chroot)
wrapper, that allows to bind mount directories specified by the user, such as
`/proc`, `/sys`, `/dev`, `/tmp`, `/run/user/<id>` and `$HOME`, before
executing any programs inside the JuNest sandbox. In case the mounting will not
work, JuNest is even providing the possibility to run the environment directly via
the pure `chroot` command.

In order to run JuNest via `chroot` solutions:

- As root via `GRoot` - Allow to have fully root privileges inside JuNest environment (you need to be root for executing this): `junest groot`

- As root via `chroot` - Allow to have fully root privileges inside JuNest environment (you need to be root for executing this): `junest root`

Execution modes comparison table
----------------
The following table shows the capabilities that each backend program is able to perform:

|     | QEMU | Root privileges required | Manage Official Packages | Manage AUR Packages | Portability | Support | User modes |
| --- | ---- | ------------------------ | ------------------------ | ------------------- | ----------- | ------- | ---------- |
| **Linux Namespaces** | NO | NO | YES | YES | Poor | YES | Normal user and `fakeroot` |
| **Proot** | YES | NO | YES | NO | YES | YES | Normal user and `fakeroot` |
| **Chroot** | NO | YES | YES | YES | YES | YES | `root` only |

Advanced usage
==============
## Build image ##
You can build a new JuNest image from scratch by running the following command:

```sh
junest build [-n]
```

The script will create a directory containing all the essentials
files in order to make JuNest working properly (such as `pacman` and `proot`).
The option `-n` will skip the final validation tests if they are not needed.
Remember that the script to build the image must run in an Arch Linux OS with
arch-install-scripts and the base-devel packages installed.
To change the build directory just use the `JUNEST_TEMPDIR` (by default /tmp).

After creating the image `junest-x86_64.tar.gz` you can install it by running:

```sh
junest setup -i junest-x86_64.tar.gz
```

For more details, you can also take a look at
[junest-builder](https://github.com/fsquillace/junest-builder)
that contains the script and systemd service used for the automatic building
of the JuNest image.

Related wiki page:

- [How to build a JuNest image using QEMU](https://github.com/fsquillace/junest/wiki/How-to-build-a-JuNest-image-using-QEMU)

## Run JuNest using a different architecture via QEMU ##
The following command will download the ARM JuNest image and will run QEMU in
case the host OS runs on `x86_64` architecture:

```sh
$> export JUNEST_HOME=~/.junest-arm
$> junest setup -a arm
$> junest proot -- uname -m
armv7l
```

## Bind directories ##
To bind a host directory to a guest location:

```sh
junest -b "--bind /home/user/mydata /mnt/mydata"
```

Or using proot arguments:

```sh
junest proot -b "-b /mnt/mydata:/home/user/mydata"
```

The option `-b` to provide options to the backend program will work with PRoot, Namespace and GRoot backend programs.
Check out the backend program options by passing `--help` option:

```sh
junest [u|g|p] -b "--help"
```

## Systemd integration ##
Although JuNest has not been designed to be a complete container, it is even possible to
virtualize the process tree thanks to the [systemd container](https://wiki.archlinux.org/index.php/Systemd-nspawn).
The JuNest containter allows to run services inside the container that can be
visible from the host OS through the network.
The drawbacks of this are that the host OS must use systemd as a service manager,
and the container can only be executed using root privileges.

To boot a JuNest container:

```sh
sudo systemd-nspawn -bD ~/.junest
```

Related wiki page:

- [How to run junest as a container](https://github.com/fsquillace/junest/wiki/How-to-run-JuNest-as-a-container)
- [How to run services using Systemd](https://github.com/fsquillace/junest/wiki/How-to-run-services-using-Systemd)

Internals
=========
## Automatic fallback for all the dependent host OS executables ##
JuNest attempts first to run the executables in the host OS located in different
positions (`/usr/bin`, `/bin`, `/usr/sbin` and `/sbin`).
As a fallback it tries to run the same executable if it is available in the JuNest
environment.

## Automatic building of the JuNest images ##
There is a periodic automation build of the JuNest images for `x86_64` arch
only.
The JuNest image for `arm` architecture may not be always up to date because
the build is performed manually.

## Static QEMU binaries ##
There are static QEMU binaries included in JuNest image that allows to run JuNest
in a different architecture from the host system. They are located in `/opt/qemu`
directory.

Troubleshooting
===============

For Arch Linux related FAQs take a look at the [General troubleshooting page](https://wiki.archlinux.org/index.php/General_troubleshooting).

## Cannot use AUR repository ##

> **Q**: Why do I get the following error when I try to install a package?

    Cannot find the gzip binary required for compressing man and info pages.

> **A**: JuNest comes with a very basic number of packages.
> In order to install AUR packages you need to install the package group `base-devel` first
> that contains all the essential packages for compiling from source code (such as gcc, make, patch, etc):

    #> pacman -S base-devel

> Remember to not install `core/sudo` as it conflicts with `junest/sudo-fake` package.

## Can't set user and group as root

> **Q**: In ns mode when installing package I get the following error:

    warning: warning given when extracting /usr/file... (Can't set user=0/group=0 for
    /usr/file...)

> **A**: This is because as fakeroot is not possible to set the owner/group of
> files as root. The package will still be installed correctly even though this
> message is showed.

## Could not change the root directory in pacman

## No servers configured for repository ##

> **Q**: Why I cannot install packages?

    #> pacman -S lsof
    Packages (1): lsof-4.88-2

    Total Download Size:    0.09 MiB
    Total Installed Size:   0.21 MiB

    error: no servers configured for repository: core
    error: no servers configured for repository: community
    error: failed to commit transaction (no servers configured for repository)
    Errors occurred, no packages were upgraded.

> **A**: You need simply to update the mirrorlist file according to your location:

    # Uncomment the repository line according to your location
    #> nano /etc/pacman.d/mirrorlist
    #> pacman -Syy

## Locate the package for a given file ##

> **Q**: How do I find which package a certain file belongs to?

> **A**: JuNest is a really small distro, therefore you frequently need to find
> the package name for a certain file. `pkgfile` is an extremely useful package
> that allows you to detect the package of a given file.
> For instance, if you want to find the package name for the command `getopt`:

    #> pacman -S pkgfile
    #> pkgfile --update
    $> pkgfile getop
    core/util-linux

> Alternatively, you can use directly `pacman` command only. Take a look [here](https://wiki.archlinux.org/index.php/General_troubleshooting#Message:_%22error_while_loading_shared_libraries%22).

## Kernel too old ##

> **Q**: Why do I get the error: "FATAL: kernel too old"?

> **A**: This is because the binaries from the precompiled package are
> compiled for Linux kernel 2.6.32. When JuNest is started without further
> options, it tries to run a shell from the JuNest chroot. The system sees that
> the host OS kernel is too old and refuses to start the shell.

> The solution is to present a higher "fake" kernel version to the JuNest
> chroot. PRoot offers the *-k* option for this, and JuNest passes this option
> on to PRoot when *-p* is prepended. For example, to fake a kernel version of
> 3.10, issue the following command:

    $> junest proot -b "-k 3.10"

> As Arch Linux ships binaries for kernel version 2.6.32, the above error is
> not unique to the precompiled package from JuNest. It will also appear when
> trying to run binaries that were later installed in the JuNest chroot with
> the `pacman` command.

> In order to check if an executable inside JuNest chroot is compatible with
> the kernel of the host OS just use the `file` command, for instance:

    $> file ~/.junest/usr/bin/bash
    ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked
    (uses shared libs), for GNU/Linux 2.6.32,
    BuildID[sha1]=ec37e49e7188ff4030052783e61b859113e18ca6, stripped

> The output shows the minimum recommended Linux kernel version.

## Kernel doesn't support private futexes ##

> **Q**: Why do I get the warning: "kompat: this kernel doesn't support private
> futexes and PRoot can't emulate them."?

> **A**: This happens on older host OS kernels when the trick of showing a fake
> kernel version to the JuNest chroot is applied (see above:
> [Kernel too old](#kernel-too-old)).

> The consequence of showing a fake kernel version to the JuNest chroot is that
> in the background, PRoot needs to translate requests from applications in the
> chroot to the old kernel of the host OS. Some of the newer kernel
> functionality can be emulated, but private futexes cannot be translated.

> Private Futexes were introduced in Linux kernel 2.6.22. Therefore, the above
> problem likely appears on old Linux systems, for example RHEL5 systems, which
> are based on Linux kernel 2.6.18. Many of the core tools like `which`, `man`,
> or `vim` run without problems while others, especially XOrg-based programs,
> are more likely to show the warning. These are also more likely to crash
> unexpectedly.

> Currently, there is no (easy) workaround for this. In order to be fully
> compatible with kernels below 2.6.22, both the precompiled package from
> JuNest and all software that is installed later needs to be compiled for this
> kernel. Most likely this can only be achieved by building the needed software
> packages from source, which kind of contradicts JuNest's distro-in-a-distro
> philosophy.

## SUID permissions ##
> **Q**: Why I do not have permissions for ping?

    $> ping www.google.com
    ping: icmp open socket: Operation not permitted

> **A**: The ping command uses *suid* permissions that allow to execute the command using
> root privileges. The fakeroot mode is not able to execute a command set with suid,
> and you may need to use root privileges. There are other few commands that
> have *suid* permission, you can list the commands from your JuNest environment
> with the following command:

    $> find /usr/bin -perm /4000

## No characters are visible on a graphic application ##

> **Q**: Why I do not see any characters in the application I have installed?

> **A**: This is probably because there are no
> [fonts](https://wiki.archlinux.org/index.php/Font_Configuration) installed in
> the system.

> To quick fix this, you can just install a fonts package:

    #> pacman -S gnu-free-fonts

## Differences between filesystem and package ownership ##

> **Q**: Why do I get warning when I install a package using root privileges?

    #> pacman -S systat
    ...
    warning: directory ownership differs on /usr/
    filesystem: 1000:100  package: 0:0
    ...

> **A**: In these cases the package installation went smoothly anyway.
> This should happen every time you install package with root privileges
> since JuNest will try to preserve the JuNest environment by assigning ownership
> of the files to the real user.

## Unprivileged user namespace disable at kernel compile time or kernel too old ##

> **Q**: Why do I get this warning when I run JuNest via Linux namespaces?

    $> junest ns
    Unprivileged user namespace is disabled at kernel compile time or kernel too old (<3.8). Proceeding anyway...

> **A**: This means that JuNest detected that the host OS either
> does not have a newer kernel version or the unprivileged user namespace
> is not enabled at kernel compile time.
> JuNest does not stop the execution of the program but it attempts to run it
> anyway. Try to use Proot as backend program in case is not possible to invoke namespaces.

## Unprivileged user namespace disabled

> **Q**: Why do I get this warning when I run JuNest via Linux namespaces?

    $> junest ns
    Unprivileged user namespace disabled. Root permissions are required to enable it: sudo sysctl kernel.unprivileged_userns_clone=1

> **A**: This means that JuNest detected that the host OS either
> does not have a newer Linux version or the user namespace is not enabled.
> JuNest does not stop the execution of the program but it attempts to run it
> anyway. If you have root permissions try to enable it, otherwise try to use
> Proot as backend program.

More documentation
==================
There are additional tutorials in the
[JuNest wiki page](https://github.com/fsquillace/junest/wiki).

Contributing
============
Contributions are welcome! You could help improving JuNest in the following ways:

- [Reporting Bugs](CONTRIBUTING.md#reporting-bugs)
- [Suggesting Enhancements](CONTRIBUTING.md#suggesting-enhancements)
- [Writing Code](CONTRIBUTING.md#your-first-code-contribution)

Donating
========
To sustain the project please consider funding by donations through
the [GitHub Sponsors page](https://github.com/sponsors/fsquillace/).

Authors
=======
JuNest was originally created in late 2014 by [Filippo Squillace (feel.sqoox@gmail.com)](https://github.com/fsquillace).

Here is a list of [**really appreciated contributors**](https://github.com/fsquillace/junest/graphs/contributors)!

[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/0)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/0)[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/1)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/1)[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/2)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/2)[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/3)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/3)[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/4)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/4)[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/5)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/5)[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/6)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/6)[![](https://sourcerer.io/fame/fsquillace/fsquillace/junest/images/7)](https://sourcerer.io/fame/fsquillace/fsquillace/junest/links/7)
