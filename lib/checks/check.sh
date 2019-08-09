#!/usr/bin/env bash
#
# This modules is used for:
#  - Running checks against the building JuNest image
#  - Integration tests on JuNest script against different execution modes (i.e. -f, -u, -r modes)
#
# Dependencies:
# - None
#
# vim: ft=sh

set -eu

OPT_RUN_ROOT_TESTS=${1:-false}
RUN_ROOT_TESTS=false
[[ ${OPT_RUN_ROOT_TESTS} == "--run-root-tests" ]] && RUN_ROOT_TESTS=true

OPT_SKIP_AUR_TESTS=${1:-false}
SKIP_AUR_TESTS=false
[[ ${OPT_SKIP_AUR_TESTS} == "--skip-aur-tests" ]] && SKIP_AUR_TESTS=true

JUNEST_HOME=${JUNEST_HOME:-$HOME/.junest}

# JUNEST_BASE can be overridden for testing purposes.
# There is no need for doing it for normal usage.
JUNEST_BASE="${JUNEST_BASE:-$(readlink -f $(dirname $(readlink -f "$0"))/../..)}"

source "${JUNEST_BASE}/lib/utils/utils.sh"
source "${JUNEST_BASE}/lib/core/common.sh"

info "Validating JuNest located in ${JUNEST_HOME}..."

info "Initial JuNest setup..."
# The following ensures that the gpg agent gets killed (if exists)
# otherwise it is not possible to exit from the session
trap "[[ -e /etc/pacman.d/gnupg/S.gpg-agent ]] && gpg-connect-agent -S /etc/pacman.d/gnupg/S.gpg-agent killagent /bye" QUIT EXIT ABRT KILL TERM INT

echo "Server = ${DEFAULT_MIRROR}" >> /etc/pacman.d/mirrorlist
pacman --noconfirm -Syy

pacman-key --init

pacman --noconfirm -S archlinux-keyring
pacman-key --populate archlinux

pacman --noconfirm -S archlinuxarm-keyring || echo "No ARM keyring detected"
pacman-key --populate archlinuxarm || echo "No ARM keyring detected"

pacman --noconfirm -Su
pacman --noconfirm -S grep coreutils
pacman --noconfirm -S $(pacman -Sg base-devel | cut -d ' ' -f 2 | grep -v sudo)

info "Checking basic executables work..."
pacman -Qi pacman 1> /dev/null
yogurt -V 1> /dev/null
/opt/proot/proot-$ARCH --help 1> /dev/null

repo_package1=tree
echo "Checking ${repo_package1} package from official repo..."
pacman --noconfirm -S ${repo_package1}
tree -L 1
pacman --noconfirm -Rsn ${repo_package1}

repo_package2=iftop
info "Checking ${repo_package2} package from official repo..."
pacman --noconfirm -S ${repo_package2}
$RUN_ROOT_TESTS && iftop -t -s 5
pacman --noconfirm -Rsn ${repo_package2}

if ! $SKIP_AUR_TESTS
then
    aur_package=aurutils
    info "Checking ${aur_package} package from AUR repo..."
    yogurt -A --noconfirm -S ${aur_package}
    aur search aur 1> /dev/null
    pacman --noconfirm -Rsn ${aur_package}
fi

# The following ensures that the gpg agent gets killed (if exists)
# otherwise it is not possible to exit from the session
if [[ -e /etc/pacman.d/gnupg/S.gpg-agent ]]
then
    gpg-connect-agent -S /etc/pacman.d/gnupg/S.gpg-agent killagent /bye || echo "GPG agent did not close properly"
    echo "GPG agent closed"
fi

exit 0
