#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# This modules is used for:
#  - Running checks against the building JuNest image
#  - Integration tests on JuNest script against different execution modes (i.e. -f, -u, -r modes)
#
# Dependencies:
# - None
#
# vim: ft=sh

set -ex


RUN_ROOT_TESTS=false
SKIP_AUR_TESTS=false
USE_SUDO=false
while [[ -n "$1" ]]
do
    case "$1" in
        --run-root-tests) RUN_ROOT_TESTS=true ; shift ;;
        --skip-aur-tests) SKIP_AUR_TESTS=true ; shift ;;
        --use-sudo) USE_SUDO=true ; shift ;;
        *) die "Invalid option $1" ;;
    esac
done

set -u

SUDO=""
[[ -n $USE_SUDO ]] && SUDO="sudo"

JUNEST_HOME=${JUNEST_HOME:-$HOME/.junest}

# JUNEST_BASE can be overridden for testing purposes.
# There is no need for doing it for normal usage.
JUNEST_BASE="${JUNEST_BASE:-$(readlink -f "$(dirname "$(readlink -f "$0")")"/../..)}"

source "${JUNEST_BASE}/lib/utils/utils.sh"
source "${JUNEST_BASE}/lib/core/common.sh"

info "Validating JuNest located in ${JUNEST_HOME}..."

info "Initial JuNest setup..."
# The following ensures that the gpg agent gets killed (if exists)
# otherwise it is not possible to exit from the session
trap "[[ -e /etc/pacman.d/gnupg/S.gpg-agent ]] && gpg-connect-agent -S /etc/pacman.d/gnupg/S.gpg-agent killagent /bye" QUIT EXIT ABRT TERM INT

PACMAN_OPTIONS="--noconfirm --disable-download-timeout"

# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -Syy

# Awk is required for pacman-key
# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -S gawk
$SUDO pacman-key --init

if [[ $(uname -m) == *"arm"* ]]
then
    # shellcheck disable=SC2086
    $SUDO pacman $PACMAN_OPTIONS -S archlinuxarm-keyring
    $SUDO pacman-key --populate archlinuxarm
else
    # shellcheck disable=SC2086
    $SUDO pacman $PACMAN_OPTIONS -S archlinux-keyring
    $SUDO pacman-key --populate archlinux
fi

# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -Su
# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -S grep coreutils
# shellcheck disable=SC2086
# shellcheck disable=SC2046
$SUDO pacman $PACMAN_OPTIONS -S $(pacman -Sg base-devel | cut -d ' ' -f 2 | grep -v sudo)

info "Checking basic executables work..."
$SUDO pacman -Qi pacman 1> /dev/null
/usr/bin/groot --help 1> /dev/null

repo_package1=tree
echo "Checking ${repo_package1} package from official repo..."
# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -S ${repo_package1}
tree -L 1
# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -Rsn ${repo_package1}

repo_package2=iftop
info "Checking ${repo_package2} package from official repo..."
# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -S ${repo_package2}
if $RUN_ROOT_TESTS
then
    # Time it out given that sometimes it gets stuck after few seconds.
    $SUDO timeout 10 iftop -t -s 5 || true
fi
# shellcheck disable=SC2086
$SUDO pacman $PACMAN_OPTIONS -Rsn ${repo_package2}

if ! $SKIP_AUR_TESTS
then
    aur_package=tcptraceroute
    info "Checking ${aur_package} package from AUR repo..."
    yay --noconfirm -S ${aur_package}
    # shellcheck disable=SC2086
    $SUDO pacman $PACMAN_OPTIONS -Rsn ${aur_package}
fi

exit 0
