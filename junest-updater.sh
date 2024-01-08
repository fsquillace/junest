#!/bin/sh

# DOWNLOAD THE ARCHIVE
wget https://github.com/ivan-hc/junest/releases/download/continuous/junest-x86_64.tar.gz

# SET APPDIR AS A TEMPORARY $HOME DIRECTORY, THIS WILL DO ALL WORK INTO THE APPDIR
HOME="$(dirname "$(readlink -f $0)")" 

# DOWNLOAD AND INSTALL JUNEST (DON'T TOUCH THIS)
git clone https://github.com/fsquillace/junest.git ~/.local/share/junest
./.local/share/junest/bin/junest setup -i junest-x86_64.tar.gz

# UPDATE ARCH LINUX IN JUNEST
./.local/share/junest/bin/junest -- sudo pacman -Syy
./.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu

# REPACK
cd ./junest
tar -czvf junest-x86_64.tar.gz .
cd ..

mv ./junest/*.tar.gz ./
