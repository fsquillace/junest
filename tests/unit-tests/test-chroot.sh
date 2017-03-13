#!/bin/bash

JUNEST_ROOT=$(readlink -f $(dirname $0)/../..)

source "$JUNEST_ROOT/tests/utils/utils.sh"

source "$JUNEST_ROOT/lib/utils/utils.sh"
source "$JUNEST_ROOT/lib/core/common.sh"
source "$JUNEST_ROOT/lib/core/chroot.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function setUp(){
    cwdSetUp
    junestSetUp
}

function tearDown(){
    junestTearDown
    cwdTearDown
}

function test_run_env_as_root_different_arch(){
    echo "JUNEST_ARCH=XXX" > ${JUNEST_HOME}/etc/junest/info
    assertCommandFailOnStatus 104 run_env_as_root pwd
}

function _test_run_env_as_root() {
    chroot_cmd() {
        [ "$JUNEST_ENV" != "1" ] && return 1
        echo $@
    }

    assertCommandSuccess run_env_as_root $@
}

function test_run_env_as_root_cmd(){
    _test_run_env_as_root pwd
    assertEquals "$JUNEST_HOME /bin/sh --login -c pwd" "$(cat $STDOUTF)"
}

function test_run_env_as_classic_root_no_cmd(){
    _test_run_env_as_root
    assertEquals "$JUNEST_HOME /bin/sh --login -c /bin/sh --login" "$(cat $STDOUTF)"
}

source $JUNEST_ROOT/tests/utils/shunit2
