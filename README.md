JuJu
====
**JuJu**: the portable GNU/Linux distribution.

Description
-----------
**JuJu** is a small and portable GNU/Linux distribution based on ArchLinux.
It allows to have an isolated GNU/Linux environment inside the home directory
without the need to have root privileges that is accessible via chroot and run
on whatever Linux distribution.

JuJu only contains the package manager (called pacman and yaourt) in order to access
to a wide range of packages from ArchLinux repositories.

The main advantage of using JuJu are:
- It gives an isolated environment in which you can install packages without affecting a production system.
- Access to a really wide range of packages even inside GNU/Linux systems that contains limited repositories (such as CentOS and RedHat).
- Install packages without the need to be root.

Quickstart
----------
After installing JuJu (see next section) you can run juju either as root or as normal user.
To run as root:

    # juju

To run as normal user:

    $ juju -n

The first time you execute it, the script will download the JuJu image and place it
to the default directory ~/.juju.

Installation
------------
Just clone JuJu somewhere (for example in ~/juju):

    $ git clone git://github.com/fsquillace/juju ~/juju
    $ export PATH=~/juju/bin:$PATH

JuJu can only works on GNU/Linux OS with kernel version greater or equal
2.6.32 on 64 bit architecture (32 bit and arm will be available soon).

Advanced usage
--------------
You can build a new JuJu image from scratch by running the following command:

    # juju -b

In this way the script will create a directory containing all the essentials
files to make JuJu working properly (such as pacman, yaourt, arch-chroot and proot).
Remember that the script to build the image must run in an ArchLinux OS with
arch-install-scripts installed.

To install the image named juju-x86\_64.tar.gz:

    # juju -i juju-x86_64.tar.gz

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
