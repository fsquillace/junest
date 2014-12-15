#!/usr/bin/env bash
#
# This file is part of JuJu: The portable GNU/Linux distribution
#
# Copyright (c) 2012-2014 Filippo Squillace <feel.squally@gmail.com>
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
[ -z ${JUJU_HOME} ] && JUJU_HOME=~/.juju
if [ -z ${JUJU_TEMPDIR} ] || [ ! -d ${JUJU_TEMPDIR} ]
then
    JUJU_TEMPDIR=/tmp
fi
JUJU_REPO=https://bitbucket.org/fsquillace/juju-repo/raw/master
ORIGIN_WD=$(pwd)

# The essentials executables that MUST exist in the host OS are (wget|curl), bash, mkdir
if command -v wget > /dev/null 2>&1
then
    WGET="wget --no-check-certificate"
elif command -v curl > /dev/null 2>&1
then
    WGET="curl -J -O -k"
else
    die "Error: Either wget or curl commands must be installed"
fi
TAR=tar

ARCH=$(uname -m)
[[ $ARCH =~ .*(armv6).* ]] && ARCH=${BASH_REMATCH[1]}

if [ $ARCH == "i686" ]
then
    LD_LIB="${JUJU_HOME}/lib/ld-linux.so.2"
elif [ $ARCH == "x86_64" ]
then
    LD_LIB="${JUJU_HOME}/lib64/ld-linux-x86-64.so.2"
elif [ $ARCH == "armv6" ]
then
    LD_LIB="${JUJU_HOME}/lib/ld-linux-armhf.so.3"
else
    die "Unknown architecture ${ARCH}"
fi

if [ -z $JUJU_ENV ] || [ "$JUJU_ENV" == "0" ]
then
    PROOT="$LD_LIB --library-path ${JUJU_HOME}/usr/lib:${JUJU_HOME}/lib ${JUJU_HOME}/usr/bin/proot"
    SH="/bin/sh --login"
elif [ "$JUJU_ENV" == "1" ]
then
    die "Error: Nested JuJu environments are not allowed"
else
    die "The variable JUJU_ENV is not properly set"
fi

CHROOT=${JUJU_HOME}/usr/bin/arch-chroot
TRUE=${JUJU_HOME}/usr/bin/true
ID="${JUJU_HOME}/usr/bin/id -u"

################################# MAIN FUNCTIONS ##############################

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
    tar -zxpf ${imagepath} -C ${JUJU_HOME}
    mkdir -p ${JUJU_HOME}/run/lock
    info "JuJu installed successfully"
}


function setup_juju(){
# Setup the JuJu environment

    local maindir=$(TMPDIR=$JUJU_TEMPDIR mktemp -d -t juju.XXXXXXXXXX)
    _prepare_build_directory

    info "Downloading JuJu..."
    builtin cd ${maindir}
    local imagefile=juju-${ARCH}.tar.gz
    $WGET ${JUJU_REPO}/${imagefile}

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


function _define_chroot_args(){
    local comm=${SH}
    [ "$1" != "" ] && comm="$@"
    echo $comm
}


function _define_proot_args(){
    local proot_args="$1"
    shift
    local comm=$(_define_chroot_args "$@")
    echo "$proot_args" "${comm[@]}"
}


function run_juju_as_root(){
    mkdir -p ${JUJU_HOME}/${HOME}
    JUJU_ENV=1 ${CHROOT} $JUJU_HOME /usr/bin/bash -c "mkdir -p /run/lock && $(_define_chroot_args "$@")"
}


function _run_juju_with_proot(){
    ${PROOT} ${TRUE} &> /dev/null || export PROOT_NO_SECCOMP=1

    [ "$(${PROOT} ${ID} 2> /dev/null )" == "0" ] && \
        die "You cannot access with root privileges. Use --root option instead."

    JUJU_ENV=1 ${PROOT} $@
    local ret=$?
    export -n PROOT_NO_SECCOMP

    return $ret
}


function run_juju_as_fakeroot(){
    local comm=$(_define_proot_args "$@")
    _run_juju_with_proot "-S" ${JUJU_HOME} ${comm}
}


function run_juju_as_user(){
    local comm=$(_define_proot_args "$@")
    _run_juju_with_proot "-R" ${JUJU_HOME} ${comm}
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
# The function must runs on ArchLinux
# The dependencies are:
# arch-install-scripts
# base-devel
# package-query
# git
    _check_package arch-install-scripts
    _check_package gcc
    _check_package package-query
    _check_package git
    local maindir=$(TMPDIR=$JUJU_TEMPDIR mktemp -d -t juju.XXXXXXXXXX)
    mkdir -p ${maindir}/root
    _prepare_build_directory
    info "Installing pacman and its dependencies..."
    pacstrap -d ${maindir}/root pacman arch-install-scripts binutils libunistring sed

    info "Generating the locales..."
    ln -sf /usr/share/zoneinfo/posix/UTC ${maindir}/root/etc/localtime
    echo "en_US.UTF-8 UTF-8" >> ${maindir}/root/etc/locale.gen
    arch-chroot ${maindir}/root locale-gen
    echo 'LANG = "en_US.UTF-8"' >> ${maindir}/root/etc/locale.conf

    info "Compiling and installing yaourt..."
    mkdir -p ${maindir}/packages/{package-query,yaourt,proot}

    builtin cd ${maindir}/packages/package-query
    $WGET https://aur.archlinux.org/packages/pa/package-query/PKGBUILD
    makepkg -sfc --asroot
    pacman --noconfirm --root ${maindir}/root -U package-query*.pkg.tar.xz

    builtin cd ${maindir}/packages/yaourt
    $WGET https://aur.archlinux.org/packages/ya/yaourt/PKGBUILD
    makepkg -sfc --asroot
    pacman --noconfirm --root ${maindir}/root -U yaourt*.pkg.tar.xz

    info "Compiling and installing proot..."
    builtin cd ${maindir}/packages/proot
    $WGET https://aur.archlinux.org/packages/pr/proot/PKGBUILD
    makepkg -sfcA --asroot
    pacman --noconfirm --root ${maindir}/root -U proot*.pkg.tar.xz

    rm ${maindir}/root/var/cache/pacman/pkg/*

    info "Copying JuJu scripts..."
    git clone https://github.com/fsquillace/juju.git ${maindir}/root/opt/juju
    echo 'export PATH=$PATH:/opt/juju/bin' > ${maindir}/root/etc/profile.d/juju.sh
    chmod +x ${maindir}/root/etc/profile.d/juju.sh

    info "Validating JuJu image..."
    arch-chroot ${maindir}/root pacman -Qi pacman &> /dev/null
    arch-chroot ${maindir}/root yaourt -V &> /dev/null
    arch-chroot ${maindir}/root proot --help &> /dev/null
    arch-chroot ${maindir}/root arch-chroot --help &> /dev/null

    builtin cd ${ORIGIN_WD}
    local imagefile="juju-${ARCH}.tar.gz"
    info "Compressing image to ${imagefile}..."
    tar -zcpf ${imagefile} -C ${maindir}/root .
    _cleanup_build_directory ${maindir}
}
