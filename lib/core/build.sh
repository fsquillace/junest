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
    prepare_archlinux
    # curl is used to download pacman.conf file
    sudo pacman -S --noconfirm git arch-install-scripts haveged curl
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

    # For some reasons, pacstrap does not create the pacman.conf file,
    # I could not reproduce the issue locally though:
    # https://app.travis-ci.com/github/fsquillace/junest/builds/268216346
    [[ -e "${maindir}"/root/etc/pacman.conf ]] || sudo curl "https://gitlab.archlinux.org/archlinux/packaging/packages/pacman/-/raw/main/pacman.conf" -o "${maindir}/root/etc/pacman.conf"

    # Pacman/pacstrap bug: https://gitlab.archlinux.org/archlinux/packaging/packages/arch-install-scripts/-/issues/3
    sudo sed -i '/^DownloadUser = alpm$/d' "${maindir}"/root/etc/pacman.conf

    sudo tee -a "${maindir}"/root/etc/pacman.conf <<EOT

[junest]
SigLevel = Optional TrustedOnly
Server = https://raw.githubusercontent.com/fsquillace/junest-repo/master/any
EOT
    info "pacman.conf being used:"
    cat "${maindir}"/root/etc/pacman.conf
    sudo pacman --noconfirm --config "${maindir}"/root/etc/pacman.conf --root "${maindir}"/root -Sy sudo-fake groot-git proot-static qemu-user-static-bin-alt yay-git

    echo "Generating the metadata info"
    sudo install -d -m 755 "${maindir}/root/etc/${CMD}"
    sudo bash -c "echo 'JUNEST_ARCH=$ARCH' > ${maindir}/root/etc/${CMD}/info"
    # Related to: https://github.com/fsquillace/junest/issues/305
    sudo bash -c "echo 'export FAKEROOTDONTTRYCHOWN=true' > ${maindir}/root/etc/profile.d/junest.sh"

    info "Generating the locales..."
    # sed command is required for locale-gen but it is required by fakeroot
    # and cannot be removed
    # localedef (called by locale-gen) requires gzip but it is supposed to be
    # already installed as systemd already depends on it
    sudo pacman --noconfirm --root "${maindir}"/root -S sed gzip
    sudo ln -sf /usr/share/zoneinfo/posix/UTC "${maindir}"/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo "${maindir}"/root/bin/groot "${maindir}"/root locale-gen
    sudo bash -c "echo LANG=\"en_US.UTF-8\" >> ${maindir}/root/etc/locale.conf"

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
