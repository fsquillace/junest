#!/usr/bin/env bash
#
# This module contains all build functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

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

function _prepare() {
    # ArchLinux System initialization
    sudo pacman --noconfirm -Syu
    sudo pacman -S --noconfirm base-devel
    sudo pacman -S --noconfirm git arch-install-scripts
}

function _install_proot_and_qemu(){
    local maindir="$1"
    local main_repo=https://s3-eu-west-1.amazonaws.com/${CMD}-repo
    proot_link=${main_repo}/proot
    qemu_link=${main_repo}/qemu

    info "Installing proot static binaries"
    sudo bash -c "
        mkdir -p '${maindir}/root/opt/proot/'
        curl '$proot_link/proot-x86_64' > '${maindir}/root/opt/proot/proot-x86_64'
        curl '$proot_link/proot-arm' > '${maindir}/root/opt/proot/proot-arm'
        chmod -R 755 '${maindir}/root/opt/proot/'
    "

    info "Installing qemu static binaries"
    sudo bash -c "
    mkdir -p '${maindir}/root/opt/qemu/'
        if [[ $ARCH == 'arm' ]]
        then
            curl '${qemu_link}/arm/qemu-arm-static-x86_64' > '${maindir}/root/opt/qemu/qemu-arm-static-x86_64'
        elif [[ $ARCH == 'x86_64' ]]
        then
            curl '${qemu_link}/x86_64/qemu-x86_64-static-arm' > '${maindir}/root/opt/qemu/qemu-x86_64-static-arm'
        fi
        chmod -R 755 '${maindir}/root/opt/qemu/'
    "
}

function build_image_env(){
    umask 022

    # The function must runs on ArchLinux with non-root privileges.
    # This is because installing AUR packages can be done by normal users only.
    (( EUID == 0 )) && \
        die "You cannot build with root privileges."

    _prepare

    local disable_validation=$1

    local maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t ${CMD}.XXXXXXXXXX)
    sudo mkdir -p ${maindir}/root
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "sudo rm -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT KILL TERM INT
    info "Installing pacman and its dependencies..."
    # All the essential executables (ln, mkdir, chown, etc) are in coreutils
    # bwrap command belongs to bubblewrap
    sudo pacstrap -G -M -d ${maindir}/root pacman coreutils bubblewrap

    if [[ $(uname -m) != *"arm"* ]]
    then
        # x86_64 does not have any mirror set by default...
        sudo bash -c "echo 'Server = $DEFAULT_MIRROR' >> ${maindir}/root/etc/pacman.d/mirrorlist"
    fi
    sudo mkdir -p ${maindir}/root/run/lock

    _install_pkg ${maindir} "$JUNEST_BASE/pkgs/sudo-fake"

    info "Installing yay..."
    sudo pacman --noconfirm -S go
    _install_pkg_from_aur ${maindir} "yay"

    _install_proot_and_qemu "${maindir}"

    echo "Generating the metadata info"
    sudo install -d -m 755 "${maindir}/root/etc/${CMD}"
    sudo bash -c "echo 'JUNEST_ARCH=$ARCH' > ${maindir}/root/etc/${CMD}/info"

    info "Generating the locales..."
    # sed command is required for locale-gen but it is required by fakeroot
    # and cannot be removed
    # localedef (called by locale-gen) requires gzip
    sudo pacman --noconfirm --root ${maindir}/root -S sed gzip
    sudo ln -sf /usr/share/zoneinfo/posix/UTC ${maindir}/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo ${JUNEST_BASE}/bin/groot ${maindir}/root locale-gen
    sudo bash -c "echo LANG=\"en_US.UTF-8\" >> ${maindir}/root/etc/locale.conf"
    sudo pacman --noconfirm --root ${maindir}/root -Rsn gzip

    info "Setting up the pacman keyring (this might take a while!)..."
    # gawk command is required for pacman-key
    sudo pacman --noconfirm --root ${maindir}/root -S gawk
    sudo ${JUNEST_BASE}/bin/groot -b /dev ${maindir}/root bash -c '
    pacman-key --init;
    for keyring_file in /usr/share/pacman/keyrings/*.gpg;
    do
        keyring=$(basename $keyring_file | cut -f 1 -d ".");
        pacman-key --populate $keyring;
    done;
    [ -e /etc/pacman.d/gnupg/S.gpg-agent ] && gpg-connect-agent -S /etc/pacman.d/gnupg/S.gpg-agent killagent /bye'
    sudo pacman --noconfirm --root ${maindir}/root -Rsn gawk

    sudo rm ${maindir}/root/var/cache/pacman/pkg/*
    # This is needed on system with busybox tar command.
    # If the file does not have write permission, the tar command to extract files fails.
    sudo chmod -R u+rw ${maindir}/root/

    mkdir -p ${maindir}/output
    builtin cd ${maindir}/output
    local imagefile="${CMD}-${ARCH}.tar.gz"
    info "Compressing image to ${imagefile}..."
    sudo $TAR -zcpf ${imagefile} -C ${maindir}/root .

    if ! $disable_validation
    then
        mkdir -p ${maindir}/root_test
        $TAR -zxpf ${imagefile} -C "${maindir}/root_test"
        JUNEST_HOME="${maindir}/root_test" ${JUNEST_BASE}/lib/checks/check_all.sh
    fi

    sudo cp ${maindir}/output/${imagefile} ${ORIGIN_WD}

    builtin cd ${ORIGIN_WD}
    trap - QUIT EXIT ABRT KILL TERM INT
    sudo rm -fr "$maindir"
}
