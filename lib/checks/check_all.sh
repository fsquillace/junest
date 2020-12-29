#!/usr/bin/env bash
# Multiple tests against different execution modes

set -ex

# JUNEST_BASE can be overridden for testing purposes.
# There is no need for doing it for normal usage.
JUNEST_BASE="${JUNEST_BASE:-$(readlink -f $(dirname $(readlink -f "$0"))/../..)}"

JUNEST_SCRIPT=${JUNEST_SCRIPT:-${JUNEST_BASE}/bin/junest}

CHECK_SCRIPT=${JUNEST_BASE}/lib/checks/check.sh

$JUNEST_SCRIPT proot --fakeroot -- "$CHECK_SCRIPT" --skip-aur-tests
$JUNEST_SCRIPT proot -- "$CHECK_SCRIPT" --skip-aur-tests --use-sudo
$JUNEST_SCRIPT ns --fakeroot -- "$CHECK_SCRIPT" --skip-aur-tests
$JUNEST_SCRIPT ns -- "$CHECK_SCRIPT" --use-sudo
sudo -E $JUNEST_SCRIPT groot -- "$CHECK_SCRIPT" --run-root-tests --skip-aur-tests

# Test the wrappers work
$JUNEST_HOME/usr/bin_wrappers/pacman --help
