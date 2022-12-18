#!/usr/bin/env bash
#
# This module contains all build functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

function _install_pkg(){
    # This function allows to install packages from AUR.
    # At the moment is not used.
    local maindir=$1
    local pkgbuilddir=$2
    # Generate a working directory because sources will be downloaded to there
    working_dir=$(TMPDIR=/tmp mktemp -d -t junest-wd.XXXXXXXXXX)
    cp -R "$pkgbuilddir"/* "$working_dir"
    builtin cd "${working_dir}" || return 1
    makepkg -sfcd
    makepkg --printsrcinfo > "${pkgbuilddir}"/.SRCINFO
    sudo pacman --noconfirm --root "${maindir}"/root -U ./*.pkg.tar.*
}

function _prepare() {
    # ArchLinux System initialization
    sudo pacman --noconfirm -Syy
    sudo pacman-key --init
    if [[ $(uname -m) == *"arm"* ]]
    then
        sudo pacman -S --noconfirm archlinuxarm-keyring
        sudo pacman-key --populate archlinuxarm
    else
        sudo pacman -S --noconfirm archlinux-keyring
        sudo pacman-key --populate archlinux
    fi

    sudo pacman --noconfirm -Su
    sudo pacman -S --noconfirm base-devel
    sudo pacman -S --noconfirm git arch-install-scripts
}

function build_image_env(){
    set -x
    umask 022

    # The function must runs on ArchLinux with non-root privileges.
    # This is because installing AUR packages can be done by normal users only.
    (( EUID == 0 )) && \
        die "You cannot build with root privileges."

    _prepare

    local disable_validation=$1

    local maindir
    maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t "${CMD}".XXXXXXXXXX)
    sudo mkdir -p "${maindir}"/root
    trap - QUIT EXIT ABRT TERM INT
    # shellcheck disable=SC2064
    trap "sudo rm -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT TERM INT
    info "Installing pacman and its dependencies..."
    # All the essential executables (ln, mkdir, chown, etc) are in coreutils
    # bwrap command belongs to bubblewrap
    sudo pacstrap -G -M "${maindir}"/root pacman coreutils bubblewrap

    if [[ ${ARCH} != "arm" ]]
    then
        # x86_64 does not have any mirror set by default...
        sudo bash -c "echo 'Server = $DEFAULT_MIRROR' >> ${maindir}/root/etc/pacman.d/mirrorlist"
    fi
    sudo mkdir -p "${maindir}"/root/run/lock

    sudo tee -a "${maindir}"/root/etc/pacman.conf > /dev/null <<EOT

[junest]
SigLevel = Optional TrustedOnly
Server = https://raw.githubusercontent.com/fsquillace/junest-repo/master/any
EOT
    sudo pacman --noconfirm --config "${maindir}"/root/etc/pacman.conf --root "${maindir}"/root -Sy sudo-fake groot-git proot-static qemu-user-static-bin-alt yay

    echo "Generating the metadata info"
    sudo install -d -m 755 "${maindir}/root/etc/${CMD}"
    sudo bash -c "echo 'JUNEST_ARCH=$ARCH' > ${maindir}/root/etc/${CMD}/info"

    info "Generating the locales..."
    # sed command is required for locale-gen but it is required by fakeroot
    # and cannot be removed
    # localedef (called by locale-gen) requires gzip
    sudo pacman --noconfirm --root "${maindir}"/root -S sed gzip
    sudo ln -sf /usr/share/zoneinfo/posix/UTC "${maindir}"/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo "${maindir}"/root/bin/groot "${maindir}"/root locale-gen
    sudo bash -c "echo LANG=\"en_US.UTF-8\" >> ${maindir}/root/etc/locale.conf"
    sudo pacman --noconfirm --root "${maindir}"/root -Rsn gzip

    info "Setting up the pacman keyring (this might take a while!)..."
    if [[ $(uname -m) == *"arm"* ]]
    then
        sudo pacman -S --noconfirm --root "${maindir}"/root archlinuxarm-keyring
    else
        sudo pacman -S --noconfirm --root "${maindir}"/root archlinux-keyring
    fi
    sudo mount --bind "${maindir}"/root "${maindir}"/root
    sudo arch-chroot "${maindir}"/root bash -c '
    set -e
    pacman-key --init;
    for keyring_file in /usr/share/pacman/keyrings/*.gpg;
    do
        keyring=$(basename $keyring_file | cut -f 1 -d ".");
        pacman-key --populate $keyring;
    done;'
    sudo umount "${maindir}"/root

    sudo rm "${maindir}"/root/var/cache/pacman/pkg/*
    # This is needed on system with busybox tar command.
    # If the file does not have write permission, the tar command to extract files fails.
    sudo chmod -R u+rw "${maindir}"/root/

    mkdir -p "${maindir}"/output
    builtin cd "${maindir}"/output || return 1
    local imagefile="${CMD}-${ARCH}.tar.gz"
    info "Compressing image to ${imagefile}..."
    sudo "$TAR" -zcpf "${imagefile}" -C "${maindir}"/root .

    if ! $disable_validation
    then
        mkdir -p "${maindir}"/root_test
        $TAR -zxpf "${imagefile}" -C "${maindir}/root_test"
        JUNEST_HOME="${maindir}/root_test" "${JUNEST_BASE}"/lib/checks/check_all.sh
    fi

    sudo cp "${maindir}"/output/"${imagefile}" "${ORIGIN_WD}"

    builtin cd "${ORIGIN_WD}" || return 1
    trap - QUIT EXIT ABRT KILL TERM INT
    sudo rm -fr "$maindir"

    set +x
}
