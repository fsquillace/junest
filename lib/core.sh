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

################################ IMPORTS #################################
# Define the variables for the dependency commands bash, wget, tar, which, awk, grep, xz, file
WGET=wget
TAR=tar
source "$(dirname ${BASH_ARGV[0]})/util.sh"

################################# VARIABLES ##############################
[ -z ${JUJU_HOME} ] && JUJU_HOME=~/.juju
JUJU_REPO=https://bitbucket.org/fsquillace/juju-repo/raw/master
JUJU_BIN=$(dirname "$0")
ORIGIN_WD=$(pwd)

################################# MAIN FUNCTIONS ##############################


function cleanup_build_directory(){
# $1: maindir (optional) - str: build directory to get rid
    local maindir=$1
    builtin cd $ORIGIN_WD
    trap - QUIT EXIT ABRT KILL TERM INT
    rm -fr "$maindir"
}


function prepare_build_directory(){
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "rm -rf ${maindir}; die \"Error occurred when installing JuJu\"" EXIT QUIT ABRT KILL TERM INT
}


function setup_juju(){
# Setup the JuJu environment
    local maindir=$(TMPDIR=/tmp mktemp -d -t juju.XXXXXXXXXX)
    prepare_build_directory

    info "Downloading JuJu..."
    builtin cd ${maindir}
    local imagefile=juju-$(uname -m).tar.gz
    wget ${JUJU_REPO}/${imagefile}

    info "Installing JuJu..."
    mkdir -p ${JUJU_HOME}
    builtin cd ${JUJU_HOME}
    tar -zxpf ${maindir}/${imagefile}
    info "JuJu installed successfully"

    cleanup_build_directory ${maindir}
}


function setup_from_file_juju(){
# Setup from file the JuJu environment
    if [ "$(ls -A $JUJU_HOME)" ]
    then
        error "Error: JuJu has been already installed in $JUJU_HOME"
        return 1
    fi

    local imagefile=$1
    if [ ! -e ${imagefile} ]
    then
        die "Error: The JuJu image file ${imagefile} does not exist"
    fi
    info "Installing JuJu from ${imagefile}..."
    mkdir -p ${JUJU_HOME}
    builtin cd ${JUJU_HOME}
    tar -zxpf ${ORIGIN_WD}/${imagefile}
    info "JuJu installed successfully"

    builtin cd $ORIGIN_WD
}


function run_juju(){
    ${JUJU_BIN}/arch-chroot $JUJU_HOME
}


function setup_and_run_juju(){
# Setup and run the JuJu environment
# The setup function will be executed only if the
# JuJu envinronment in $JUJU_HOME is not present.

    [ ! "$(ls -A $JUJU_HOME)" ] && setup_juju
    run_juju
}


