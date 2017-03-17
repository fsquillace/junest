#!/usr/bin/env bash
#
# This module contains all build functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

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
    makepkg -sfc
    sudo pacman --noconfirm --root ${maindir}/root -U ${pkgname}*.pkg.tar.xz
}

function build_image_env(){
    umask 022

    # The function must runs on ArchLinux with non-root privileges.
    (( EUID == 0 )) && \
        die "You cannot build with root privileges."

    _check_package arch-install-scripts
    _check_package gcc
    _check_package package-query
    _check_package git

    local disable_validation=$1
    local skip_root_tests=$2

    local maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t ${CMD}.XXXXXXXXXX)
    sudo mkdir -p ${maindir}/root
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "sudo rm -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT KILL TERM INT
    info "Installing pacman and its dependencies..."
    # The archlinux-keyring and libunistring are due to missing dependencies declaration in ARM archlinux
    # All the essential executables (ln, mkdir, chown, etc) are in coreutils
    # yaourt requires sed
    # localedef (called by locale-gen) requires gzip
    sudo pacstrap -G -M -d ${maindir}/root pacman coreutils libunistring archlinux-keyring sed gzip
    sudo bash -c "echo 'Server = $DEFAULT_MIRROR' >> ${maindir}/root/etc/pacman.d/mirrorlist"
    sudo mkdir -p ${maindir}/root/run/lock

    # AUR packages requires non-root user to be compiled. proot fakes the user to 10
    info "Compiling and installing yaourt..."
    _install_from_aur ${maindir} "package-query"
    _install_from_aur ${maindir} "yaourt"

    info "Install ${NAME} script..."
    sudo pacman --noconfirm --root ${maindir}/root -S git
    _install_from_aur ${maindir} "${CMD}-git" "${CMD}.install"
    sudo pacman --noconfirm --root ${maindir}/root -Rsn git

    info "Generating the locales..."
    # sed command is required for locale-gen
    sudo ln -sf /usr/share/zoneinfo/posix/UTC ${maindir}/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo ${maindir}/root/opt/junest/bin/groot ${maindir}/root locale-gen
    sudo bash -c "echo LANG=\"en_US.UTF-8\" >> ${maindir}/root/etc/locale.conf"

    info "Setting up the pacman keyring (this might take a while!)..."
    sudo ${maindir}/root/opt/junest/bin/groot ${maindir}/root bash -c \
        "pacman-key --init; pacman-key --populate archlinux; [ -e /etc/pacman.d/gnupg/S.gpg-agent ] && gpg-connect-agent -S /etc/pacman.d/gnupg/S.gpg-agent killagent /bye"

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
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r yogurt -V 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -- yogurt -V 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -f -- yogurt -V 1> /dev/null
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
    local aur_package=tcptraceroute
    info "Installing ${aur_package} package from AUR repo using proot..."
    JUNEST_HOME=${testdir} ${cmd} -f -- yogurt -A --noconfirm -S ${aur_package}
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r tcptraceroute localhost

    info "Removing the previous packages..."
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -Rsn tcptraceroute tree iftop

}
