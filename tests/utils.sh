function install_executable(){
    for i in $( ldd $* | grep -v dynamic | cut -d " " -f 3 | sed 's/://' | sort | uniq )
      do
        cp --parents $i $JUJU_HOME
      done
    # ARCH amd64
    if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
       cp --parents /lib64/ld-linux-x86-64.so.2 $JUJU_HOME
    fi
    # ARCH i386
    if [ -f  /lib/ld-linux.so.2 ]; then
       cp --parents /lib/ld-linux.so.2 $JUJU_HOME
    fi
    cp --parent $* $JUJU_HOME/
}

function install_package(){
    pacman -Ql $1 | grep "/$" | sed 's/.* //' | xargs -I {} mkdir -p $JUJU_HOME/{}
    pacman -Ql $1 | grep -v "/$" | sed 's/.* //' | xargs -I {} cp -f -a --parents {} $JUJU_HOME
    #export -f install_executable
    #export JUJU_HOME
    #pacman -Ql $1 | sed 's/.* //' | grep "^/usr/bin/" | xargs -I {} bash -ic "install_executable {}"
}

function install_mini_juju(){
    mkdir -p ${JUJU_HOME}/{proc,bin,sys,dev,run,tmp,etc}
    touch ${JUJU_HOME}/etc/resolv.conf
    mkdir -p ${JUJU_HOME}/usr/bin
    #echo "root:x:0:0:root:/root:/bin/bash" > ${JUJU_HOME}/etc/passwd
    #cp /etc/nsswitch.conf ${JUJU_HOME}
    cp /usr/bin/arch-chroot ${JUJU_HOME}/usr/bin
    install_executable /usr/bin/bash
    install_executable /usr/bin/ls
    install_executable /usr/bin/whoami
    install_executable /usr/bin/grep
    install_executable /usr/bin/mkdir
    install_executable /usr/bin/proot
    install_package bash
    install_package talloc
    install_package proot
    install_package coreutils
    install_package grep
    ln -s /usr/bin/bash $JUJU_HOME/bin/sh
}


function is_equal(){
    [ "$1" == "$2" ] || return 1 && return 0
}


