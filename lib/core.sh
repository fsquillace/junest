#!/usr/bin/env bash
#
# This file is part of JuJu (https://github.com/fsquillace/juju).
#
# Copyright (c) 2012-2015
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Library General Public License as published
# by the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# References:
# https://wiki.archlinux.org/index.php/PKGBUILD
# https://wiki.archlinux.org/index.php/Creating_Packages

set -e

################################ IMPORTS #################################
source "$(dirname ${BASH_ARGV[0]})/util.sh"

################################# VARIABLES ##############################

if [ "$JUJU_ENV" == "1" ]
then
    die "Error: Nested JuJu environments are not allowed"
elif [ ! -z $JUJU_ENV ] && [ "$JUJU_ENV" != "0" ]
then
    die "The variable JUJU_ENV is not properly set"
fi

[ -z ${JUJU_HOME} ] && JUJU_HOME=~/.juju
if [ -z ${JUJU_TEMPDIR} ] || [ ! -d ${JUJU_TEMPDIR} ]
then
    JUJU_TEMPDIR=/tmp
fi
JUJU_REPO=https://bitbucket.org/fsquillace/juju-repo/raw/master
ORIGIN_WD=$(pwd)

WGET="wget --no-check-certificate"
CURL="curl -L -J -O -k"

TAR=tar

HOST_ARCH=$(uname -m)

if [ $HOST_ARCH == "i686" ] || [ $HOST_ARCH == "i386" ]
then
    ARCH="x86"
    LD_LIB="${JUJU_HOME}/lib/ld-linux.so.2"
elif [ $HOST_ARCH == "x86_64" ]
then
    ARCH="x86_64"
    LD_LIB="${JUJU_HOME}/lib64/ld-linux-x86-64.so.2"
elif [[ $HOST_ARCH =~ .*(arm).* ]]
then
    ARCH="arm"
    LD_LIB="${JUJU_HOME}/lib/ld-linux-armhf.so.3"
else
    die "Unknown architecture ${ARCH}"
fi

PROOT_COMPAT="${JUJU_HOME}/opt/proot/proot-${ARCH}"
PROOT_LINK=http://static.proot.me/proot-${ARCH}

SH=("/bin/sh" "--login")
CHROOT=${JUJU_HOME}/usr/bin/arch-chroot
TRUE=/usr/bin/true
ID="/usr/bin/id -u"
CHOWN="/usr/bin/chown"

################################# MAIN FUNCTIONS ##############################

function download(){
    $WGET $1 || $CURL $1 || \
        die "Error: Both wget and curl commands have failed on downloading $1"
}

function is_juju_installed(){
    [ -d "$JUJU_HOME" ] && [ "$(ls -A $JUJU_HOME)" ] && return 0
    return 1
}


function _cleanup_build_directory(){
# $1: maindir (optional) - str: build directory to get rid
    local maindir=$1
    builtin cd $ORIGIN_WD
    trap - QUIT EXIT ABRT KILL TERM INT
    rm -fr "$maindir"
}


function _prepare_build_directory(){
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "rm -rf ${maindir}; die \"Error occurred when installing JuJu\"" EXIT QUIT ABRT KILL TERM INT
}


function _setup_juju(){
    is_juju_installed && die "Error: JuJu has been already installed in $JUJU_HOME"
    mkdir -p "${JUJU_HOME}"
    imagepath=$1
    $TAR -zxpf ${imagepath} -C ${JUJU_HOME}
    mkdir -p ${JUJU_HOME}/run/lock
    warn "Warn: Change the mirrorlist file according to your location:"
    info "    nano /etc/pacman.d/mirrorlist"
    info "    pacman -Syy"
    info "JuJu installed successfully"
}


function setup_juju(){
# Setup the JuJu environment

    local maindir=$(TMPDIR=$JUJU_TEMPDIR mktemp -d -t juju.XXXXXXXXXX)
    _prepare_build_directory

    info "Downloading JuJu..."
    builtin cd ${maindir}
    local imagefile=juju-${ARCH}.tar.gz
    download ${JUJU_REPO}/${imagefile}

    info "Installing JuJu..."
    _setup_juju ${maindir}/${imagefile}

    _cleanup_build_directory ${maindir}
}


function setup_from_file_juju(){
# Setup from file the JuJu environment

    local imagefile=$1
    [ ! -e ${imagefile} ] && die "Error: The JuJu image file ${imagefile} does not exist"

    info "Installing JuJu from ${imagefile}..."
    _setup_juju ${imagefile}

    builtin cd $ORIGIN_WD
}


function run_juju_as_root(){
    local main_cmd="${SH[@]}"
    [ "$1" != "" ] && main_cmd="$@"

    local uid=$UID
    [ -z $SUDO_UID ] || uid=$SUDO_UID:$SUDO_GID

    local cmd="
mkdir -p ${JUJU_HOME}/${HOME}
mkdir -p /run/lock
${main_cmd}
"

    JUJU_ENV=1 ${CHROOT} $JUJU_HOME /usr/bin/bash -c "${cmd}"

    # The ownership of the files in JuJu is assigned to the real user
    [ -z $uid ] || ${CHOWN} -R ${uid} ${JUJU_HOME}
}

function _run_proot(){
    local proot_args="$1"
    shift
    if ${PROOT_COMPAT} $proot_args ${TRUE} &> /dev/null
    then
        JUJU_ENV=1 ${PROOT_COMPAT} $proot_args "${@}"
    elif PROOT_NO_SECCOMP=1 ${PROOT_COMPAT} $proot_args ${TRUE} &> /dev/null
    then
        warn "Proot error: Trying to execute proot with PROOT_NO_SECCOMP=1..."
        JUJU_ENV=1 PROOT_NO_SECCOMP=1 ${PROOT_COMPAT} $proot_args "${@}"
    else
        die "Error: Check if the juju arguments are correct or use the option juju -p \"-k 3.10\""
    fi
}


function _run_juju_with_proot(){
    local proot_args="$1"
    shift

    if [ "$1" != "" ]
    then
        _run_proot "${proot_args}" "${@}"
    else
        _run_proot "${proot_args}" "${SH[@]}"
    fi
}


function run_juju_as_fakeroot(){
    local proot_args="$1"
    shift
    [ "$(_run_proot "-R ${JUJU_HOME} $proot_args" ${ID} 2> /dev/null )" == "0" ] && \
        die "You cannot access with root privileges. Use --root option instead."
    _run_juju_with_proot "-S ${JUJU_HOME} $proot_args" "${@}"
}


function run_juju_as_user(){
    local proot_args="$1"
    shift
    [ "$(_run_proot "-R ${JUJU_HOME} $proot_args" ${ID} 2> /dev/null )" == "0" ] && \
        die "You cannot access with root privileges. Use --root option instead."
    _run_juju_with_proot "-R ${JUJU_HOME} $proot_args" "${@}"
}


function delete_juju(){
    ! ask "Are you sure to delete JuJu located in ${JUJU_HOME}" "N" && return
    if mountpoint -q ${JUJU_HOME}
    then
        info "There are mounted directories inside ${JUJU_HOME}"
        if ! umount --force ${JUJU_HOME}
        then
            error "Cannot umount directories in ${JUJU_HOME}"
            die "Try to delete juju using root permissions"
        fi
    fi
    # the CA directories are read only and can be deleted only by changing the mod
    chmod -R +w ${JUJU_HOME}/etc/ca-certificates
    if rm -rf ${JUJU_HOME}/*
    then
        info "JuJu deleted in ${JUJU_HOME}"
    else
        error "Error: Cannot delete JuJu in ${JUJU_HOME}"
    fi
}


function _check_package(){
    if ! pacman -Qq $1 > /dev/null
    then
        die "Package $1 must be installed"
    fi
}


function build_image_juju(){
# The function must runs on ArchLinux with non-root privileges.
    [ "$(${ID})" == "0" ] && \
        die "You cannot build with root privileges."

    _check_package arch-install-scripts
    _check_package gcc
    _check_package package-query
    _check_package git

    local disable_validation=$1

    local maindir=$(TMPDIR=$JUJU_TEMPDIR mktemp -d -t juju.XXXXXXXXXX)
    sudo mkdir -p ${maindir}/root
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "sudo rm -rf ${maindir}; die \"Error occurred when installing JuJu\"" EXIT QUIT ABRT KILL TERM INT
    info "Installing pacman and its dependencies..."
    # The archlinux-keyring and libunistring are due to missing dependencies declaration in ARM archlinux
    # yaourt requires sed
    sudo pacstrap -G -M -d ${maindir}/root pacman arch-install-scripts binutils libunistring nano archlinux-keyring sed

    info "Generating the locales..."
    # sed command is required for locale-gen
    sudo ln -sf /usr/share/zoneinfo/posix/UTC ${maindir}/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo arch-chroot ${maindir}/root locale-gen
    sudo bash -c "echo 'LANG = \"en_US.UTF-8\"' >> ${maindir}/root/etc/locale.conf"

    info "Installing compatibility binary proot"
    sudo mkdir -p ${maindir}/root/opt/proot
    builtin cd ${maindir}/root/opt/proot
    sudo $CURL $PROOT_LINK
    sudo chmod +x proot-$ARCH

    # AUR packages requires non-root user to be compiled. proot fakes the user to 10
    info "Compiling and installing yaourt..."
    mkdir -p ${maindir}/packages/{package-query,yaourt}

    builtin cd ${maindir}/packages/package-query
    download https://aur.archlinux.org/packages/pa/package-query/PKGBUILD
    makepkg -sfc
    sudo pacman --noconfirm --root ${maindir}/root -U package-query*.pkg.tar.xz

    builtin cd ${maindir}/packages/yaourt
    download https://aur.archlinux.org/packages/ya/yaourt/PKGBUILD
    makepkg -sfc
    sudo pacman --noconfirm --root ${maindir}/root -U yaourt*.pkg.tar.xz
    # Apply patches for yaourt and makepkg
    sudo mkdir -p ${maindir}/root/opt/yaourt/bin/
    sudo cp ${maindir}/root/usr/bin/yaourt ${maindir}/root/opt/yaourt/bin/
    sudo sed -i -e 's/"--asroot"//' ${maindir}/root/opt/yaourt/bin/yaourt
    sudo cp ${maindir}/root/usr/bin/makepkg ${maindir}/root/opt/yaourt/bin/
    sudo sed -i -e 's/EUID\s==\s0/false/' ${maindir}/root/opt/yaourt/bin/makepkg
    sudo bash -c "echo 'export PATH=/opt/yaourt/bin:$PATH' > ${maindir}/root/etc/profile.d/juju.sh"
    sudo chmod +x ${maindir}/root/etc/profile.d/juju.sh

    info "Copying JuJu scripts..."
    sudo git clone https://github.com/fsquillace/juju.git ${maindir}/root/opt/juju

    info "Setting up the pacman keyring (this might take a while!)..."
    sudo arch-chroot ${maindir}/root bash -c "pacman-key --init; pacman-key --populate archlinux"

    sudo rm ${maindir}/root/var/cache/pacman/pkg/*

    mkdir -p ${maindir}/output
    builtin cd ${maindir}/output
    local imagefile="juju-${ARCH}.tar.gz"
    info "Compressing image to ${imagefile}..."
    sudo $TAR -zcpf ${imagefile} -C ${maindir}/root .

    $disable_validation || validate_image "${maindir}" "${imagefile}"

    sudo cp ${maindir}/output/${imagefile} ${ORIGIN_WD}

    builtin cd ${ORIGIN_WD}
    trap - QUIT EXIT ABRT KILL TERM INT
    sudo rm -fr "$maindir"
}

function validate_image(){
    local maindir=$1
    local imagefile=$2
    info "Validating JuJu image..."
    mkdir -p ${maindir}/root_test
    $TAR -zxpf ${imagefile} -C ${maindir}/root_test
    mkdir -p ${maindir}/root_test/run/lock
    sed -i -e "s/#Server/Server/" ${maindir}/root_test/etc/pacman.d/mirrorlist
    ${maindir}/root/opt/proot/proot-$ARCH -S ${maindir}/root_test pacman --noconfirm -Syy

    sudo ${maindir}/root/usr/bin/arch-chroot ${maindir}/root_test pacman -Qi pacman 1> /dev/null
    sudo ${maindir}/root/usr/bin/arch-chroot ${maindir}/root_test yaourt -V 1> /dev/null
    sudo ${maindir}/root/usr/bin/arch-chroot ${maindir}/root_test /opt/proot/proot-$ARCH --help 1> /dev/null
    sudo ${maindir}/root/usr/bin/arch-chroot ${maindir}/root_test arch-chroot --help 1> /dev/null

    ${maindir}/root/opt/proot/proot-$ARCH -S ${maindir}/root_test pacman --noconfirm -S base-devel
    local yaourt_package=tcptraceroute
    info "Installing ${yaourt_package} package from AUR repo using proot..."
    ${maindir}/root/opt/proot/proot-$ARCH -S ${maindir}/root_test sh --login -c "yaourt --noconfirm -S ${yaourt_package}"
    sudo ${maindir}/root/usr/bin/arch-chroot ${maindir}/root_test tcptraceroute localhost

    local repo_package=sysstat
    info "Installing ${repo_package} package from official repo using proot..."
    ${maindir}/root/opt/proot/proot-$ARCH -S ${maindir}/root_test pacman --noconfirm -S ${repo_package}
    ${maindir}/root/opt/proot/proot-$ARCH -R ${maindir}/root_test iostat
    ${maindir}/root/opt/proot/proot-$ARCH -S ${maindir}/root_test iostat

    local repo_package=iftop
    info "Installing ${repo_package} package from official repo using root..."
    ${maindir}/root/opt/proot/proot-$ARCH -S ${maindir}/root_test pacman --noconfirm -S ${repo_package}
    sudo ${maindir}/root/usr/bin/arch-chroot ${maindir}/root_test iftop -t -s 5
}
