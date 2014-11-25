function install_executable(){
    for i in $( ldd $* | grep -v dynamic | cut -d " " -f 3 | sed 's/://' | sort | uniq )
    do
        cp -f --parents $i $JUJU_HOME
    done

    # ARCH amd64
    if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
       cp -f --parents /lib64/ld-linux-x86-64.so.2 $JUJU_HOME
    fi

    # ARCH i386
    if [ -f  /lib/ld-linux.so.2 ]; then
       cp -f --parents /lib/ld-linux.so.2 $JUJU_HOME
    fi

    cp -f --parents $* $JUJU_HOME/
}

function install_package(){
    # Copy the directories
    pacman -Ql $1 | grep "/$" | sed 's/.* //' | xargs -I {} mkdir -p $JUJU_HOME/{}

    # Copy the files
    pacman -Ql $1 | grep -v "/$" | sed 's/.* //' | xargs -I {} cp -f --parents {} $JUJU_HOME

    # Copy the dynamic libraries of the executables
    #export -f install_executable
    #export JUJU_HOME
    #pacman -Ql $1 | grep -v "/$" | sed 's/.* //' | grep "^/usr/bin/" | xargs -I {} bash -ic "install_executable {}"
}

function install_mini_juju(){
    install_package filesystem 2> /dev/null
    install_package arch-install-scripts
    install_package bash
    install_package proot
    install_package coreutils
    install_executable /usr/bin/bash
    install_executable /usr/bin/ls
    install_executable /usr/bin/mkdir
    install_executable /usr/bin/proot
}


function is_equal(){
    [ "$1" == "$2" ] || return 1 && return 0
}


