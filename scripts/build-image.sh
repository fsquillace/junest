#!/bin/bash

#sudo apt-get -y install virtualbox vagrant

#sudo /sbin/vboxconfig

#git clone https://github.com/fsquillace/junest-vagrant.git junest-vagrant

#cd junest-vagrant
#ARCH=x86_64
#PROVIDER=virtualbox
#VAGRANT_VAGRANTFILE=Vagrantfile-$ARCH vagrant up --provider=$PROVIDER

echo $PATH
which junest

pacman -Sy --noconfirm base-devel git arch-install-scripts
/home/travis/build/fsquillace/junest/bin/junest -b
