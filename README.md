JuJu
====
**JuJu**: the GNU/Linux distribution container for non-root users

Description
-----------
**JuJu** is a small ArchLinux based GNU/Linux distribution.

It allows to have an isolated GNU/Linux environment inside any generic host GNU/Linux OS
and without the need to have root privileges for installing packages.

JuJu contains just the package managers (called pacman and yaourt) that allows to access
to a wide range of packages from ArchLinux repositories.

The main advantages on using JuJu are:
- Install packages without root privileges.
- Isolated environment in which you can install packages without affecting a production system.
- Access to a wide range of packages in particular on GNU/Linux distros that may contain a limited repositories (such as CentOS and RedHat).
- Available for x86\_64, i686 and ARMv6 architectures but you can build you own image from scratch too!
- All ArchLinux lovers can have their favourite distro everywhere!

Quickstart
----------
There are three different ways you can run JuJu:

- As normal user - Allow to make basic operations using [proot](https://wiki.archlinux.org/index.php/Proot):
```
$ juju
```
- As fakeroot - Allow to install/remove packages using [proot](https://wiki.archlinux.org/index.php/Proot):
```
$ juju -f
```
- As root - Allow to have fully root privileges inside JuJu environment using [arch-chroot](https://wiki.archlinux.org/index.php/Chroot) (you need to be root for executing this):
```
# juju -r
```

The first time you execute it, the script will download the JuJu image and place it
to the default directory ~/.juju.
You can change the default directory by changing the environment variable *JUJU\_HOME*.

Installation
------------
Just clone JuJu somewhere (for example in ~/juju):

    $ git clone git://github.com/fsquillace/juju ~/juju
    $ export PATH=~/juju/bin:$PATH

JuJu can only works on GNU/Linux OS with kernel version greater or equal
2.6.32 on 64 bit 32 bit and ARMv6 architectures.

Advanced usage
--------------
### Build image ###
You can build a new JuJu image from scratch by running the following command:
```
    # juju -b
```
In this way the script will create a directory containing all the essentials
files in order to make JuJu working properly (such as pacman, yaourt, arch-chroot and proot).
Remember that the script to build the image must run in an ArchLinux OS with
arch-install-scripts, package-query, git and the base-devel packages installed.
To change the build directory just use the *JUJU_TEMPDIR* (by default /tmp).

After creating the image juju-x86\_64.tar.gz you can install it by running:

    # juju -i juju-x86_64.tar.gz

### Bind directories ###
To bind and host directory to a guest location, you can use proot arguments:
```
    $ juju -p "-b /mnt/mydata:/home/user/mydata"
```

Check out the proot options with:
```
    $ juju -p "--help"
```

Dependencies
------------
JuJu comes with a very short list of dependencies in order to be installed in most
of GNU/Linux distributions. The dependencies needed in the host OS are:
- bash
- wget or curl
- tar
- mkdir
- linux kernel 2.6.32+

Troubleshooting
---------------

###Cannot use AUR repository###
- **Q**: Why do I get the following error when I try to install a package with yaourt?
```
Cannot find the gzip binary required for compressing man and info pages.
```
- **A**: JuJu comes with a very basic number of packages.
In order to install packages using yaourt you may need to install the package group *base-devel*
that contains all the essential packages for compiling source code (such as gcc, make, patch, etc):

```
    pacman -S base-devel
```

###Kernel too old###
- **Q**: Why do I get the error: "FATAL: kernel too old"?
- **A**: This is because the executable from the precompiled package cannot
always run if the kernel is old.
In order to check if the executable can be compatible with the kernel of
the host OS just use file command, for instance:

```
    file ~/.juju/usr/bin/bash
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
have *suid* permission, you can list the commands from your JuJu environment
with the following command:
```
    find /usr/bin -perm +4000
```

###No characters are visible on a graphic application###
- **Q**: Why I do not see any characters in the application I have installed?

- **A**: This is probably because there are no 
[https://wiki.archlinux.org/index.php/Font_Configuration](fonts) installed in
the system.

To quick fix this, you can just install a fonts package:
```
    pacman -S gnu-free-fonts
```

###Missing permissions on removing a package###
- **Q**: Why I cannot remove the package I have installed?
```
    pacman -Rsn lsof
    checking dependencies...

    Packages (1): lsof-4.88-1

    Total Removed Size:   0.21 MiB

    error: cannot remove /usr/share/licenses/lsof/LICENSE (Permission denied)
    error: could not remove database entry lsof-4.88-1
```

- **A**: This is probably because you have installed the package with root
permissions. Since JuJu gives the possibility to install packages
either as root or as normal user you need to remember that and remove
the package with the right user!

License
-------
Copyright (c) 2012-2014

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

## Author
Filippo Squillace <feel.squally@gmail.com>

## WWW
https://github.com/fsquillace/juju
