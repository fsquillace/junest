#!/bin/sh
set -ex

VERSION=$1

cd /tmp
wget http://ftp.gnu.org/gnu/bash/bash-$VERSION.tar.gz

tar -zxf bash-$VERSION.tar.gz
cd /tmp/bash-$VERSION*
./configure
make
sudo make install
