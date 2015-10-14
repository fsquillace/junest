#!/usr/bin/env bash
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

NAME='JuNest'
CMD='junest'
VERSION='4.7.4'
CODE_NAME='Mairei'
DESCRIPTION='The Arch Linux based distro that runs upon any Linux distros without root access'
AUTHOR='Filippo Squillace <feel dot sqoox at gmail.com>'
HOMEPAGE="https://github.com/fsquillace/${CMD}"
COPYRIGHT='2012-2015'


if [ "$JUNEST_ENV" == "1" ]
then
    die "Error: Nested ${NAME} environments are not allowed"
elif [ ! -z $JUNEST_ENV ] && [ "$JUNEST_ENV" != "0" ]
then
    die "The variable JUNEST_ENV is not properly set"
fi

[ -z ${JUNEST_HOME} ] && JUNEST_HOME=~/.${CMD}
[ -z ${JUNEST_BASE} ] && JUNEST_BASE=${JUNEST_HOME}/opt/junest
if [ -z ${JUNEST_TEMPDIR} ] || [ ! -d ${JUNEST_TEMPDIR} ]
then
    JUNEST_TEMPDIR=/tmp
fi

# The update of the variable PATH ensures that the executables are
# found on different locations
PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH

# The executable uname is essential in order to get the architecture
# of the host system, so a fallback mechanism cannot be used for it.
UNAME=uname

ARCH_LIST=('x86_64' 'x86' 'arm')
HOST_ARCH=$($UNAME -m)
if [ $HOST_ARCH == "i686" ] || [ $HOST_ARCH == "i386" ]
then
    ARCH="x86"
    LD_LIB="${JUNEST_HOME}/lib/ld-linux.so.2"
elif [ $HOST_ARCH == "x86_64" ]
then
    ARCH="x86_64"
    LD_LIB="${JUNEST_HOME}/lib64/ld-linux-x86-64.so.2"
elif [[ $HOST_ARCH =~ .*(arm).* ]]
then
    ARCH="arm"
    LD_LIB="${JUNEST_HOME}/lib/ld-linux-armhf.so.3"
else
    die "Unknown architecture ${ARCH}"
fi

PROOT_LINK=http://static.proot.me/
MAIN_REPO=https://dl.dropboxusercontent.com/u/42449030
ENV_REPO=${MAIN_REPO}/${CMD}
DEFAULT_MIRROR='https://mirrors.kernel.org/archlinux/$repo/os/$arch'

ORIGIN_WD=$(pwd)

################################ EXECUTABLES ##################################
# This section contains all the executables needed for JuNest to run properly.
# They are based on a fallback mechanism that tries to use the executable in
# different locations in the host OS.

# List of executables that are run inside JuNest:
SH=("/bin/sh" "--login")

# List of executables that are run in the host OS:
PROOT_COMPAT="${JUNEST_HOME}/opt/proot/proot-${ARCH}"
CHROOT=${JUNEST_BASE}/bin/jchroot
CLASSIC_CHROOT="chroot"
WGET="wget --no-check-certificate"
CURL="curl -L -J -O -k"
TAR=tar
CHOWN="chown"

LD_EXEC="$LD_LIB --library-path ${JUNEST_HOME}/usr/lib:${JUNEST_HOME}/lib"

# The following functions attempt first to run the executable in the host OS.
# As a last hope they try to run the same executable available in the JuNest
# image.

function ln_cmd(){
    ln $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/ln $@
}

function rm_cmd(){
    rm $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/rm $@
}

function chown_cmd(){
    $CHOWN $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/chown $@
}

function mkdir_cmd(){
    mkdir $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/mkdir $@
}

function proot_cmd(){
     ${PROOT_COMPAT} "${@}" || PROOT_NO_SECCOMP=1 ${PROOT_COMPAT} "${@}" || \
        die "Error: Check if the ${CMD} arguments are correct or use the option ${CMD} -p \"-k 3.10\""
}

function download_cmd(){
    $WGET $@ || $CURL $@
}

function chroot_cmd(){
    $CHROOT "$@" || $CLASSIC_CHROOT "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/chroot "$@"
}

################################# MAIN FUNCTIONS ##############################

function is_env_installed(){
    [ -d "$JUNEST_HOME" ] && [ "$(ls -A $JUNEST_HOME)" ] && return 0
    return 1
}


function _cleanup_build_directory(){
# $1: maindir (optional) - str: build directory to get rid
    local maindir=$1
    builtin cd $ORIGIN_WD
    trap - QUIT EXIT ABRT KILL TERM INT
    rm_cmd -fr "$maindir"
}


function _prepare_build_directory(){
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "rm_cmd -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT KILL TERM INT
}


function _setup_env(){
    is_env_installed && die "Error: ${NAME} has been already installed in $JUNEST_HOME"
    mkdir_cmd -p "${JUNEST_HOME}"
    imagepath=$1
    $TAR -zxpf ${imagepath} -C ${JUNEST_HOME}
    mkdir_cmd -p ${JUNEST_HOME}/run/lock
    info "The default mirror URL is ${DEFAULT_MIRROR}."
    info "Remember to refresh the package databases from the server:"
    info "    pacman -Syy"
    info "${NAME} installed successfully"
}


function setup_env(){
    local arch=$ARCH
    [ -z $1 ] || arch="$1"
    contains_element $arch "${ARCH_LIST[@]}" || \
        die "The architecture is not one of: ${ARCH_LIST[@]}"

    local maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t ${CMD}.XXXXXXXXXX)
    _prepare_build_directory

    info "Downloading ${NAME}..."
    builtin cd ${maindir}
    local imagefile=${CMD}-${arch}.tar.gz
    download_cmd ${ENV_REPO}/${imagefile}

    info "Installing ${NAME}..."
    _setup_env ${maindir}/${imagefile}

    _cleanup_build_directory ${maindir}
}


function setup_env_from_file(){
    local imagefile=$1
    [ ! -e ${imagefile} ] && die "Error: The ${NAME} image file ${imagefile} does not exist"

    info "Installing ${NAME} from ${imagefile}..."
    _setup_env ${imagefile}

    builtin cd $ORIGIN_WD
}

function run_env_as_root(){
    source ${JUNEST_HOME}/etc/junest/info
    [ "$JUNEST_ARCH" != "$ARCH" ] && \
        die "The host system architecture is not correct: $ARCH != $JUNEST_ARCH"

    local uid=$UID
    # SUDO_USER is more reliable compared to SUDO_UID
    [ -z $SUDO_USER ] || uid=$SUDO_USER:$SUDO_GID

    local main_cmd="${SH[@]}"
    [ "$1" != "" ] && main_cmd="$(insert_quotes_on_spaces "$@")"

    # With chown the ownership of the files is assigned to the real user
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "[ -z $uid ] || chown_cmd -R ${uid} ${JUNEST_HOME}; rm_cmd -f ${JUNEST_HOME}/etc/mtab" EXIT QUIT ABRT KILL TERM INT

    [ ! -e ${JUNEST_HOME}/etc/mtab ] && ln_cmd -s /proc/self/mounts ${JUNEST_HOME}/etc/mtab

    JUNEST_ENV=1 chroot_cmd "$JUNEST_HOME" "${SH[@]}" "-c" "${main_cmd}"
}

function _run_env_with_proot(){
    local proot_args="$1"
    shift

    if [ "$1" != "" ]
    then
        JUNEST_ENV=1 proot_cmd ${proot_args} "${SH[@]}" "-c" "$(insert_quotes_on_spaces "${@}")"
    else
        JUNEST_ENV=1 proot_cmd ${proot_args} "${SH[@]}"
    fi
}

function _run_env_with_qemu(){
    local proot_args="$1"
    source ${JUNEST_HOME}/etc/junest/info

    if [ "$JUNEST_ARCH" != "$ARCH" ]
    then
        local qemu_bin="qemu-$JUNEST_ARCH-static-$ARCH"
        local qemu_symlink="/tmp/${qemu_bin}-$RANDOM"
        trap - QUIT EXIT ABRT KILL TERM INT
        trap "[ -e ${qemu_symlink} ] && rm_cmd -f ${qemu_symlink}" EXIT QUIT ABRT KILL TERM INT

        warn "Emulating $NAME via QEMU..."
        [ -e ${qemu_symlink} ] || \
            ln_cmd -s ${JUNEST_HOME}/opt/qemu/${qemu_bin} ${qemu_symlink}
        proot_args="-q ${qemu_symlink} $proot_args"
    fi
    shift
    _run_env_with_proot "$proot_args" "${@}"
}

function run_env_as_fakeroot(){
    (( EUID == 0 )) && \
        die "You cannot access with root privileges. Use --root option instead."
    [ ! -e ${JUNEST_HOME}/etc/mtab ] && ln_cmd -s /proc/self/mounts ${JUNEST_HOME}/etc/mtab
    _run_env_with_qemu "-S ${JUNEST_HOME} $1" "${@:2}"
}

function run_env_as_user(){
    (( EUID == 0 )) && \
        die "You cannot access with root privileges. Use --root option instead."
    [ -e ${JUNEST_HOME}/etc/mtab ] && rm_cmd -f ${JUNEST_HOME}/etc/mtab
    _run_env_with_qemu "-R ${JUNEST_HOME} $1" "${@:2}"
}


function delete_env(){
    ! ask "Are you sure to delete ${NAME} located in ${JUNEST_HOME}" "N" && return
    if mountpoint -q ${JUNEST_HOME}
    then
        info "There are mounted directories inside ${JUNEST_HOME}"
        if ! umount --force ${JUNEST_HOME}
        then
            error "Cannot umount directories in ${JUNEST_HOME}"
            die "Try to delete ${NAME} using root permissions"
        fi
    fi
    # the CA directories are read only and can be deleted only by changing the mod
    chmod -R +w ${JUNEST_HOME}/etc/ca-certificates
    if rm_cmd -rf ${JUNEST_HOME}/*
    then
        info "${NAME} deleted in ${JUNEST_HOME}"
    else
        error "Error: Cannot delete ${NAME} in ${JUNEST_HOME}"
    fi
}


function _check_package(){
    if ! pacman -Qq $1 > /dev/null
    then
        die "Package $1 must be installed"
    fi
}

function _install_from_aur(){
    local maindir=$1
    local pkgname=$2
    local installname=$3
    mkdir -p ${maindir}/packages/${pkgname}
    builtin cd ${maindir}/packages/${pkgname}
    $CURL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${pkgname}"
    [ -z "${installname}" ] || $CURL "https://aur.archlinux.org/cgit/aur.git/plain/${installname}?h=${pkgname}"
    makepkg -sfc --noconfirm
    sudo pacman --noconfirm --root ${maindir}/root -U ${pkgname}*.pkg.tar.xz
}

function build_image_env(){
# The function must run on ArchLinux with non-root privileges.
    (( EUID == 0 )) && \
        die "You cannot build with root privileges."

    _check_package arch-install-scripts
    _check_package gcc
    _check_package package-query
    _check_package git
    _check_package yaourt

    local disable_validation=$1
    shift
    local skip_root_tests=$1
    shift
    local extra_packages="$@"

    local maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t ${CMD}.XXXXXXXXXX)
    sudo mkdir -p ${maindir}/root
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "sudo rm -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT KILL TERM INT
    info "Installing pacman and its dependencies..."
    # The archlinux-keyring and libunistring are due to missing dependencies declaration in ARM archlinux
    # All the essential executables (ln, mkdir, chown, etc) are in coreutils
    # yaourt requires sed
    sudo pacstrap -G -M -d ${maindir}/root pacman coreutils libunistring archlinux-keyring sed
    sudo bash -c "echo 'Server = $DEFAULT_MIRROR' >> ${maindir}/root/etc/pacman.d/mirrorlist"

    info "Generating the locales..."
    # sed command is required for locale-gen
    sudo ln -sf /usr/share/zoneinfo/posix/UTC ${maindir}/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo arch-chroot ${maindir}/root locale-gen
    sudo bash -c "echo 'LANG = \"en_US.UTF-8\"' >> ${maindir}/root/etc/locale.conf"

    info "Generating the metadata info..."
    sudo mkdir ${maindir}/root/etc/${CMD}
    sudo bash -c "echo 'JUNEST_ARCH=$ARCH' > ${maindir}/root/etc/${CMD}/info"

    info "Installing compatibility binaries proot"
    sudo mkdir -p ${maindir}/root/opt/proot
    builtin cd ${maindir}/root/opt/proot
    for arch in ${ARCH_LIST[@]}
    do
        info "Downloading $PROOT_LINK/proot-$arch ..."
        sudo $CURL $PROOT_LINK/proot-$arch
        sudo chmod +x proot-$arch
    done

    info "Installing qemu static binaries"
    sudo mkdir -p ${maindir}/root/opt/qemu
    builtin cd ${maindir}/root/opt/qemu
    for arch in ${ARCH_LIST[@]}
    do
        if [ "$arch" != "$ARCH" ]
        then
            info "Downloading qemu-$ARCH-static-$arch ..."
            sudo $CURL ${MAIN_REPO}/qemu/$ARCH/qemu-$ARCH-static-$arch
            sudo chmod +x qemu-$ARCH-static-$arch
        fi
    done

    # AUR packages requires non-root user to be compiled. proot fakes the user to 10
    info "Compiling and installing yaourt..."
    _install_from_aur ${maindir} "package-query"

    _install_from_aur ${maindir} "yaourt"
    # Apply patches for yaourt and makepkg
    sudo mkdir -p ${maindir}/root/opt/yaourt/bin/
    sudo cp ${maindir}/root/usr/bin/yaourt ${maindir}/root/opt/yaourt/bin/
    sudo sed -i -e 's/"--asroot"//' ${maindir}/root/opt/yaourt/bin/yaourt
    sudo cp ${maindir}/root/usr/bin/makepkg ${maindir}/root/opt/yaourt/bin/
    sudo sed -i -e 's/EUID\s==\s0/false/' ${maindir}/root/opt/yaourt/bin/makepkg
    sudo bash -c "echo 'export PATH=/opt/yaourt/bin:\$PATH' > ${maindir}/root/etc/profile.d/${CMD}.sh"
    sudo chmod +x ${maindir}/root/etc/profile.d/${CMD}.sh

    info "Install ${NAME} script..."
    sudo pacman --noconfirm --root ${maindir}/root -S git
    _install_from_aur ${maindir} "${CMD}-git" "${CMD}.install"
    sudo pacman --noconfirm --root ${maindir}/root -Rsn git

    info "Setting up the pacman keyring (this might take a while!)..."
    sudo arch-chroot ${maindir}/root bash -c "pacman-key --init; pacman-key --populate archlinux"

    local extra
    for extra in $extra_packages
    do
        info "Installing $extra additional package..."
        yaourt --root ${maindir}/root -A --noconfirm -S ${extra}
    done

    sudo rm ${maindir}/root/var/cache/pacman/pkg/*

    mkdir -p ${maindir}/output
    builtin cd ${maindir}/output
    local imagefile="${CMD}-${ARCH}.tar.gz"
    info "Compressing image to ${imagefile}..."
    sudo $TAR -zcpf ${imagefile} -C ${maindir}/root .

    if ! $disable_validation
    then
        mkdir -p ${maindir}/root_test
        $TAR -zxpf ${imagefile} -C "${maindir}/root_test"
        check_env "${maindir}/root_test" "${maindir}/root_test/opt/${CMD}/bin/${CMD}" $skip_root_tests
    fi

    sudo cp ${maindir}/output/${imagefile} ${ORIGIN_WD}

    builtin cd ${ORIGIN_WD}
    trap - QUIT EXIT ABRT KILL TERM INT
    sudo rm -fr "$maindir"
}

function check_env(){
    local testdir=$1
    local cmd=$2
    local skip_root_tests=$3
    info "Validating ${NAME} located in ${testdir} using the ${cmd} script..."
    echo "Server = ${DEFAULT_MIRROR}" >> ${testdir}/etc/pacman.d/mirrorlist
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -Syy

    # Check most basic executables work
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r pacman -Qi pacman 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -- pacman -Qi pacman 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -f -- pacman -Qi pacman 1> /dev/null
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r yaourt -V 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -- yaourt -V 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -f -- yaourt -V 1> /dev/null
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r /opt/proot/proot-$ARCH --help 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -- /opt/proot/proot-$ARCH --help 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -f -- /opt/proot/proot-$ARCH --help 1> /dev/null

    local repo_package=tree
    info "Installing ${repo_package} package from official repo using proot..."
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -S ${repo_package}
    JUNEST_HOME=${testdir} ${cmd} tree
    JUNEST_HOME=${testdir} ${cmd} -f tree

    local repo_package=iftop
    info "Installing ${repo_package} package from official repo using root..."
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -S ${repo_package}
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r iftop -t -s 5

    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -S base-devel
    local yaourt_package=tcptraceroute
    info "Installing ${yaourt_package} package from AUR repo using proot..."
    JUNEST_HOME=${testdir} ${cmd} -f -- yaourt -A --noconfirm -S ${yaourt_package}
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r tcptraceroute localhost

    info "Removing the previous packages..."
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -Rsn tcptraceroute tree iftop

}
