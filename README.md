JuJu
====
**JuJu**: the portable GNU/Linux distribution.

Description
-----------
**JuJu** is a small and portable GNU/Linux distribution based on ArchLinux.

JuJu can be used inside another GNU/Linx OS via chroot. It only contains the package manager (called pacman) in order to access to a wide range of packages from ArchLinux repositories.

The main advantage of using JuJu is because you have an isolated environment in which you can install
packages without affecting a production system. Another advantage is that with JuJu
you can access to a really wide range of packages inside GNU/Linux systems that contains
limited repositories (such as CentOS and RedHat).

Quickstart
----------
After installing JuJu (See next section) just run the main juju script:
```bash
juju
```
The first time you execute it, the script will download the JuJu image and place it
to the default directory ~/.juju.
You will need root privileges in order to acces to the chroot.

Installation
------------
Just clone JuJu somewhere (for example in ~/juju):

```bash
git clone git://github.com/fsquillace/juju ~/juju
export PATH=~/juju/bin:$PATH
```

JuJu can only works on GNU/Linux OS with kernel version greater or equal
2.6.32 in 32 or 64 bit.
