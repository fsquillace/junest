JuNest
======
The Arch Linux based distro that runs upon any Linux distros without root access.

|Project Status|Donation|Communication|
|:------------:|:------:|:-----------:|
| [![Build status](https://api.travis-ci.org/fsquillace/junest.png?branch=master)](https://travis-ci.org/fsquillace/junest) [![OpenHub](https://www.openhub.net/p/junest/widgets/project_thin_badge.gif)](https://www.openhub.net/p/junest) | [![PayPal](https://img.shields.io/badge/PayPal-Donate%20a%20beer-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=8LEHQKBCYTACY) | [![Join the gitter chat at https://gitter.im/fsquillace/junest](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/fsquillace/junest?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Join the IRC chat at https://webchat.freenode.net/?channels=junest](https://img.shields.io/badge/IRC-JuNest-yellow.svg)](https://webchat.freenode.net/?channels=junest) [![Join the group at https://groups.google.com/d/forum/junest](https://img.shields.io/badge/Google Groups-JuNest-red.svg)](https://groups.google.com/d/forum/junest) |

**Table of Contents**
- [Description](#description)
- [Quickstart](#quickstart)
- [Installation](#installation)
- [Dependencies](#dependencies)
- [Advanced usage](#advanced-usage)
- [Internals](#internals)
- [Troubleshooting](#troubleshooting)
- [More documentation](#more documentation)
- [License](#license)
- [Author](#author)
- [WWW](#www)

Description
===========
**JuNest** (Jailed User NEST) is a lightweight Arch Linux based distribution that allows to have
an isolated GNU/Linux environment inside any generic host GNU/Linux OS
and without the need to have root privileges for installing packages.

JuNest contains mainly the package managers (called [pacman](https://wiki.archlinux.org/index.php/Pacman) and [yaourt](https://wiki.archlinux.org/index.php/Yaourt)) that allows to access
to a wide range of packages from the Arch Linux repositories.

The main advantages on using JuNest are:

- Install packages without root privileges.
- Isolated environment in which you can install packages without affecting a production system.
- Access to a wide range of packages in particular on GNU/Linux distros that may contain limited repositories (such as CentOS and RedHat).
- Available for x86\_64, x86 and ARM architectures but you can build your own image from scratch too!
- Run on a different architecture from the host OS via QEMU
- All Arch Linux lovers can have their favourite distro everywhere!

JuNest follows the [Arch Linux philosophy](https://wiki.archlinux.org/index.php/The_Arch_Way).

Quickstart
==========
There are three different ways you can run JuNest:

- As normal user - Allow to make basic operations: ```junest```

- As fakeroot - Allow to install/remove packages: ```junest -f```

- As root - Allow to have fully root privileges inside JuNest environment (you need to be root for executing this): ```junest -r```

If the JuNest image has not been downloaded yet, the script will download
the image and will place it to the default directory ~/.junest.
You can change the default directory by changing the environment variable *JUNEST\_HOME*.

If you are new on Archlinux and you are not familiar with *pacman* package manager
visit the [pacman rosetta page](https://wiki.archlinux.org/index.php/Pacman_Rosetta).

Installation
============
JuNest can works on GNU/Linux OS with kernel version greater or equal
2.6.0 (JuNest was not tested on kernel versions older than this) on 64 bit, 32 bit and ARM architectures.

## Method one (Recommended) ##
Just clone the JuNest repo somewhere (for example in ~/junest):

    git clone git://github.com/fsquillace/junest ~/junest
    export PATH=~/junest/bin:$PATH

### Installation using AUR (Arch Linux only) ###
If you are using an Arch Linux system you can, alternatively, install JuNest from the [AUR repository](https://aur.archlinux.org/):

    yaourt -S junest-git
    export PATH=/opt/junest/bin:$PATH

## Method two ##
Alternatively, another installation method would be to directly download the JuNest image and place it to the default directory ~/.junest:

    ARCH=<one of "x86_64", "x86", "arm">
    mkdir ~/.junest
    curl https://dl.dropboxusercontent.com/u/42449030/junest/junest-${ARCH}.tar.gz | tar -xz -C ~/.junest
    export PATH=~/.junest/opt/junest/bin:$PATH

Dependencies
============
JuNest comes with a very short list of dependencies in order to be installed in most
of GNU/Linux distributions. The needed executables in the host OS are:

- bash
- chown (for root access only)
- ln
- mkdir
- rm
- tar
- uname
- wget or curl

The minimum recommended linux kernel is 2.6.0+

Advanced usage
==============

## Build image ##
You can build a new JuNest image from scratch by running the following command:

    junest -b [-n]

The script will create a directory containing all the essentials
files in order to make JuNest working properly (such as pacman, yaourt and proot).
The option **-n** will skip the final validation tests if they are not needed.
Remember that the script to build the image must run in an Arch Linux OS with
arch-install-scripts, package-query, git and the base-devel packages installed.
To change the build directory just use the *JUNEST_TEMPDIR* (by default /tmp).

After creating the image junest-x86\_64.tar.gz you can install it by running:

    junest -i junest-x86_64.tar.gz

For more details, you can also take a look at
[junest-builder](https://github.com/fsquillace/junest-builder)
that contains the script and systemd service used for the automatic building
of the JuNest image.

Related wiki page:

- [How to build a JuNest image using QEMU](https://github.com/fsquillace/junest/wiki/How-to-build-a-JuNest-image-using-QEMU)

## Run JuNest using a different architecture via QEMU ##
The following command will download the ARM JuNest image and will run QEMU in
case the host OS runs on either x86\_64 or x86 architectures:

    $> JUNEST_HOME=~/.junest-arm junest -a arm -- uname -m
    armv7l

## Bind directories ##
To bind a host directory to a guest location, you can use proot arguments:

    junest -p "-b /mnt/mydata:/home/user/mydata"

Check out the proot options with:

    junest -p "--help"

## JuNest as a container ##
Although JuNest has not been designed to be a complete container, it is even possible to
virtualize the process tree thanks to the [systemd container](https://wiki.archlinux.org/index.php/Systemd-nspawn).
The JuNest containter allows to run services inside the container that can be
visible from the host OS through the network.
The drawbacks of this are that the host OS must use systemd as a service manager,
and the container can only be executed using root privileges.

To boot a JuNest container:

    sudo systemd-nspawn -bD ~/.junest

Related wiki page:

- [How to run junest as a container](https://github.com/fsquillace/junest/wiki/How-to-run-JuNest-as-a-container)

Internals
=========

There are two main chroot jail used in JuNest.
The main one is [proot](https://wiki.archlinux.org/index.php/Proot) which
allows unprivileged users to execute programs inside a sandbox and
jchroot, a small and portable version of
[arch-chroot](https://wiki.archlinux.org/index.php/Chroot) which is an
enhanced chroot for privileged users that mounts the primary directories
(i.e. /proc, /sys, /dev and /run) before executing any programs inside
the sandbox.

##Automatic fallback to classic chroot##
If jchroot fails for some reasons in the host system (i.e. it is not able to
mount one of the directories),
JuNest automatically tries to fallback to the classic chroot.

##Automatic fallback for all the dependent host OS executables##
JuNest attempt first to run the executables in the host OS located in different
positions (/usr/bin, /bin, /usr/sbin and /sbin).
As a fallback it tries to run the same executable if it is available in the JuNest
image.

##Automatic building of the JuNest images##
The JuNest images are built every week so that you can always get the most
updated package versions.

##Static QEMU binaries##
There are static QEMU binaries included in JuNest image that allows to run JuNest
in a different architecture from the host system. They are located in `/opt/qemu`
directory.

Troubleshooting
===============

##Cannot use AUR repository##

> **Q**: Why do I get the following error when I try to install a package with yaourt?

    Cannot find the gzip binary required for compressing man and info pages.

> **A**: JuNest comes with a very basic number of packages.
> In order to install packages using yaourt you may need to install the package group **base-devel**
> that contains all the essential packages for compiling source code (such as gcc, make, patch, etc):

    pacman -S base-devel

##Kernel too old##

> **Q**: Why do I get the error: "FATAL: kernel too old"?

> **A**: This is because the executable from the precompiled package cannot
> properly run if the kernel is old.
> You may need to specify the PRoot *-k* option if the guest rootfs
> requires a newer kernel version:

    junest -p "-k 3.10"

> In order to check if an executable inside JuNest environment can be compatible
> with the kernel of the host OS just use the *file* command, for instance:

    file ~/.junest/usr/bin/bash
    ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked
    (uses shared libs), for GNU/Linux 2.6.32,
    BuildID[sha1]=ec37e49e7188ff4030052783e61b859113e18ca6, stripped

> From the output you can see what is the minimum recommended Linux kernel version.

##SUID permissions##
> **Q**: Why I do not have permissions for ping?

    ping www.google.com
    ping: icmp open socket: Operation not permitted

> **A**: The ping command uses *suid* permissions that allow to execute the command using
> root privileges. The fakeroot mode is not able to execute a command set with suid,
> and you may need to use root privileges. There are other few commands that
> have *suid* permission, you can list the commands from your JuNest environment
> with the following command:

    find /usr/bin -perm +4000

##No characters are visible on a graphic application##

> **Q**: Why I do not see any characters in the application I have installed?

> **A**: This is probably because there are no
> [fonts](https://wiki.archlinux.org/index.php/Font_Configuration) installed in
> the system.

> To quick fix this, you can just install a fonts package:

    pacman -S gnu-free-fonts

##Differences between filesystem and package ownership##

> **Q**: Why do I get warning when I install a package using root privileges?

    pacman -S systat
    ...
    warning: directory ownership differs on /usr/
    filesystem: 1000:100  package: 0:0
    ...

> **A**: In these cases the package installation went smoothly anyway.
> This should happen every time you install package with root privileges
> since JuNest will try to preserve the JuNest environment by assigning ownership
> of the files to the real user.

##No servers configured for repository##

> **Q**: Why I cannot install packages?

    pacman -S lsof
    Packages (1): lsof-4.88-2

    Total Download Size:    0.09 MiB
    Total Installed Size:   0.21 MiB

    error: no servers configured for repository: core
    error: no servers configured for repository: community
    error: failed to commit transaction (no servers configured for repository)
    Errors occurred, no packages were upgraded.

> **A**: You need simply to update the mirrorlist file according to your location:

    # Uncomment the repository line according to your location
    nano /etc/pacman.d/mirrorlist
    pacman -Syy

More documentation
==================
There are additional tutorials in the
[JuNest wiki page](https://github.com/fsquillace/junest/wiki).

License
=======
Copyright (c) 2012-2015

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU Library General Public License as published
by the Free Software Foundation; either version 2, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Author
======
Filippo Squillace <feel.sqoox@gmail.com>

WWW
===
https://github.com/fsquillace/junest
