JuJube
====
**JuJube**: the Arch Linux based distro that runs upon any Linux distros without root access

[![Build status](https://api.travis-ci.org/fsquillace/jujube.png?branch=master)](https://travis-ci.org/fsquillace/jujube)

Description
-----------
**JuJube** is a lightweight Arch Linux based distribution that allows to have
an isolated GNU/Linux environment inside any generic host GNU/Linux OS
and without the need to have root privileges for installing packages.

JuJube contains mainly the package managers (called pacman and yaourt) that allows to access
to a wide range of packages from the Arch Linux repositories.

The main advantages on using JuJube are:
- Install packages without root privileges.
- Isolated environment in which you can install packages without affecting a production system.
- Access to a wide range of packages in particular on GNU/Linux distros that may contain limited repositories (such as CentOS and RedHat).
- Available for x86\_64, x86 and ARM architectures but you can build your own image from scratch too!
- All Arch Linux lovers can have their favourite distro everywhere!

JuJube follows the [Arch Linux philosophy](https://wiki.archlinux.org/index.php/The_Arch_Way).

Quickstart
----------
There are three different ways you can run JuJube:

- As normal user - Allow to make basic operations using [proot](https://wiki.archlinux.org/index.php/Proot):

    jujube

- As fakeroot - Allow to install/remove packages using [proot](https://wiki.archlinux.org/index.php/Proot):

    jujube -f

- As root - Allow to have fully root privileges inside JuJube environment using [arch-chroot](https://wiki.archlinux.org/index.php/Chroot) (you need to be root for executing this):

    jujube -r

If the JuJube image has not been downloaded yet, the script will download
the JuJube image and will place it to the default directory ~/.jujube.
You can change the default directory by changing the environment variable *JUJUBE\_HOME*.

If you are new on Archlinux and you are not familiar with *pacman* package manager
visit the [pacman rosetta page](https://wiki.archlinux.org/index.php/Pacman_Rosetta).

Installation
------------
Just clone the JuJube repo somewhere (for example in ~/jujube):

    git clone git://github.com/fsquillace/jujube ~/jujube
    export PATH=~/jujube/bin:$PATH

Alternatively, another installation method would be to directly download the JuJube image and place it to the default directory ~/.jujube:

    ARCH=<one of "x86_64", "x86", "arm">
    mkdir ~/.jujube
    curl https://dl.dropboxusercontent.com/u/42449030/jujube/jujube-${ARCH}.tar.gz | tar -xz -C ~/.jujube
    export PATH=~/.jujube/opt/jujube/bin:$PATH

JuJube can works on GNU/Linux OS with kernel version greater or equal
2.6.0 (JuJube was not tested on kernel versions older than this) on 64 bit, 32 bit and ARM architectures.

Advanced usage
--------------
### Build image ###
You can build a new JuJube image from scratch by running the following command:

    jujube -b [-n]

The script will create a directory containing all the essentials
files in order to make JuJube working properly (such as pacman, yaourt, arch-chroot and proot).
The option `-n` will skip the final validation tests if they are not needed.
Remember that the script to build the image must run in an Arch Linux OS with
arch-install-scripts, package-query, git and the base-devel packages installed.
To change the build directory just use the *JUJUBE_TEMPDIR* (by default /tmp).

After creating the image jujube-x86\_64.tar.gz you can install it by running:

    jujube -i jujube-x86_64.tar.gz

Related wiki page:
- [How to build a JuJube image using QEMU](https://github.com/fsquillace/jujube/wiki/How-to-build-a-JuJube-image-using-QEMU)

### Bind directories ###
To bind a host directory to a guest location, you can use proot arguments:

    jujube -p "-b /mnt/mydata:/home/user/mydata"

Check out the proot options with:

    jujube -p "--help"

###Automatic fallback to classic chroot###
Since the [arch-chroot](https://wiki.archlinux.org/index.php/Chroot) may not work
on some distros, JuJube automatically tries to fallback to the classic chroot.

### JuJube as a container ###
Although JuJube has not been designed to be a complete container, it is even possible to
virtualize the process tree thanks to the [systemd container](https://wiki.archlinux.org/index.php/Systemd-nspawn).
The JuJube containter allows to run services inside the container that can be
visible from the host OS through the network.
The drawbacks of this are that the host OS must use systemd as a service manager,
and the container can only be executed using root privileges.

To boot a JuJube container:

    sudo systemd-nspawn -bD ~/.jujube

Related wiki page:
- [How to run jujube as a container](https://github.com/fsquillace/jujube/wiki/How-to-run-JuJube-as-a-container)

Dependencies
------------
JuJube comes with a very short list of dependencies in order to be installed in most
of GNU/Linux distributions. The needed executables in the host OS are:
- bash
- wget or curl
- tar
- mkdir
- ln
- chown (for root access only)

The minimum recommended linux kernel is 2.6.0+

Troubleshooting
---------------

###Cannot use AUR repository###
- **Q**: Why do I get the following error when I try to install a package with yaourt?
```
Cannot find the gzip binary required for compressing man and info pages.
```
- **A**: JuJube comes with a very basic number of packages.
In order to install packages using yaourt you may need to install the package group *base-devel*
that contains all the essential packages for compiling source code (such as gcc, make, patch, etc):

```
    pacman -S base-devel
```

###Kernel too old###
- **Q**: Why do I get the error: "FATAL: kernel too old"?
- **A**: This is because the executable from the precompiled package cannot
properly run if the kernel is old.
JuJube contains two different PRoot binaries, and one of them is highly compatible
with old linux kernel versions. JuJube will detect which PRoot binary need to be
executed but you may need to specify the PRoot *-k* option if the guest rootfs
requires a newer kernel version:
```
    jujube -p "-k 3.10"
```

In order to check if an executable inside JuJube environment can be compatible
with the kernel of the host OS just use the *file* command, for instance:

```
    file ~/.jujube/usr/bin/bash
    ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked
    (uses shared libs), for GNU/Linux 2.6.32,
    BuildID[sha1]=ec37e49e7188ff4030052783e61b859113e18ca6, stripped
```

From the output you can see what is the minimum recommended Linux kernel version.

###SUID permissions###
- **Q**: Why I do not have permissions for ping?
```
    ping www.google.com
    ping: icmp open socket: Operation not permitted
```

- **A**: The ping command uses *suid* permissions that allow to execute the command using
root privileges. The fakeroot mode is not able to execute a command set with suid,
and you may need to use root privileges. There are other few commands that
have *suid* permission, you can list the commands from your JuJube environment
with the following command:
```
    find /usr/bin -perm +4000
```

###No characters are visible on a graphic application###
- **Q**: Why I do not see any characters in the application I have installed?

- **A**: This is probably because there are no 
[fonts](https://wiki.archlinux.org/index.php/Font_Configuration) installed in
the system.

To quick fix this, you can just install a fonts package:
```
    pacman -S gnu-free-fonts
```

###Differences between filesystem and package ownership###
- **Q**: Why do I get warning when I install a package using root privileges?
```
    pacman -S systat
    ...
    warning: directory ownership differs on /usr/
    filesystem: 1000:100  package: 0:0
    ...
```

- **A**: In these cases the package installation went smoothly anyway.
This should happen every time you install package with root privileges
since JuJube will try to preserve the JuJube environment by assigning ownership
of the files to the real user.

###No servers configured for repository###
- **Q**: Why I cannot install packages?
```
    pacman -S lsof
    Packages (1): lsof-4.88-2

    Total Download Size:    0.09 MiB
    Total Installed Size:   0.21 MiB

    error: no servers configured for repository: core
    error: no servers configured for repository: community
    error: failed to commit transaction (no servers configured for repository)
    Errors occurred, no packages were upgraded.
```

- **A**: You need simply to update the mirrorlist file according to your location:
```
    # Uncomment the repository line according to your location
    nano /etc/pacman.d/mirrorlist
    pacman -Syy
```

License
-------
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
------
Filippo Squillace <feel.squally@gmail.com>

WWW
---
https://github.com/fsquillace/jujube

Last words
---------
Quote of the [lotus](http://en.wikipedia.org/wiki/Ziziphus_lotus) (a selvatic jujube plant)

> Per nove infausti dì sul mar pescoso  
> i venti rei mi trasportaro. Al fine  
> nel decimo sbarcammo in su le rive  
> de’ Lotofági, un popolo, a cui cibo  
> È d’una pianta il florido germoglio.  
> ...  
> ...  
> Partiro e s’affrontaro a quella gente,  
> che, lunge dal voler la vita loro,  
> il dolce loto a savorar lor porse.  
> chiunque l’esca dilettosa, e nuova  
> gustato avea, con le novelle indietro  
> non bramava tornar: colà bramava  
> starsi, e, mangiando del soave loto,  
> la contrada natia sbandir dal petto.  

verse 105-123, Homer, from [Odyssey Book IX](http://it.wikisource.org/wiki/Odissea/Libro_IX)
([en](http://en.wikisource.org/wiki/The_Odyssey_(Butler)/Book_IX))
