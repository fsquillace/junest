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

function _install_pkg_from_aur(){
    local maindir=$1
    local pkgname=$2
    local installname=$3
    mkdir -p ${maindir}/packages/${pkgname}
    builtin cd ${maindir}/packages/${pkgname}
    $CURL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${pkgname}"
    [ -z "${installname}" ] || $CURL "https://aur.archlinux.org/cgit/aur.git/plain/${installname}?h=${pkgname}"
    makepkg -sfcd
    sudo pacman --noconfirm --root ${maindir}/root -U ${pkgname}*.pkg.tar.xz
}

function _install_pkg(){
    local maindir=$1
    local pkgbuilddir=$2
    builtin cd ${pkgbuilddir}
    makepkg -sfcd
    sudo pacman --noconfirm --root ${maindir}/root -U *.pkg.tar.xz
}

function build_image_env(){
    umask 022

    # The function must runs on ArchLinux with non-root privileges.
    (( EUID == 0 )) && \
        die "You cannot build with root privileges."

    _check_package arch-install-scripts
    _check_package gcc

    local disable_validation=$1

    local maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t ${CMD}.XXXXXXXXXX)
    sudo mkdir -p ${maindir}/root
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "sudo rm -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT KILL TERM INT
    info "Installing pacman and its dependencies..."
    # The archlinux-keyring and libunistring are due to missing dependencies declaration in ARM archlinux
    # All the essential executables (ln, mkdir, chown, etc) are in coreutils
    # unshare command belongs to util-linux
    sudo pacstrap -G -M -d ${maindir}/root pacman coreutils libunistring archlinux-keyring util-linux
    sudo bash -c "echo 'Server = $DEFAULT_MIRROR' >> ${maindir}/root/etc/pacman.d/mirrorlist"
    sudo mkdir -p ${maindir}/root/run/lock

    # AUR packages requires non-root user to be compiled. proot fakes the user to 10
    _install_pkg ${maindir} "$JUNEST_BASE/pkgs/sudo-fake"

    info "Install ${NAME} script..."
    _install_pkg_from_aur ${maindir} "${CMD}-git" "${CMD}.install"

    info "Generating the locales..."
    # sed command is required for locale-gen
    # localedef (called by locale-gen) requires gzip
    sudo pacman --noconfirm --root ${maindir}/root -S sed gzip
    sudo ln -sf /usr/share/zoneinfo/posix/UTC ${maindir}/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo ${maindir}/root/opt/junest/bin/groot ${maindir}/root locale-gen
    sudo bash -c "echo LANG=\"en_US.UTF-8\" >> ${maindir}/root/etc/locale.conf"
    sudo pacman --noconfirm --root ${maindir}/root -Rsn sed gzip

    info "Setting up the pacman keyring (this might take a while!)..."
    sudo ${maindir}/root/opt/junest/bin/groot -b /dev ${maindir}/root bash -c \
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
        JUNEST_HOME="${maindir}/root_test" ${JUNEST_BASE}/bin/${CMD} proot -f ${JUNEST_BASE}/lib/checks/check.sh
        JUNEST_HOME="${maindir}/root_test" ${JUNEST_BASE}/bin/${CMD} ns ${JUNEST_BASE}/lib/checks/check.sh
        JUNEST_HOME="${maindir}/root_test" sudo -E ${JUNEST_BASE}/bin/${CMD} groot ${JUNEST_BASE}/lib/checks/check.sh --run-root-tests
    fi

    sudo cp ${maindir}/output/${imagefile} ${ORIGIN_WD}

    builtin cd ${ORIGIN_WD}
    trap - QUIT EXIT ABRT KILL TERM INT
    sudo rm -fr "$maindir"
}
