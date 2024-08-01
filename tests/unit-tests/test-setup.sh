#!/bin/bash
# shellcheck disable=SC1091

JUNEST_ROOT=$(readlink -f "$(dirname "$0")"/../..)

source "$JUNEST_ROOT/tests/utils/utils.sh"

source "$JUNEST_ROOT/lib/utils/utils.sh"
source "$JUNEST_ROOT/lib/core/common.sh"
source "$JUNEST_ROOT/lib/core/setup.sh"

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

function test_is_env_installed(){
    rm -rf "${JUNEST_HOME:?}"/*
    assertCommandFail is_env_installed
    touch "$JUNEST_HOME"/just_file
    assertCommandSuccess is_env_installed
}

function test_setup_env(){
    rm -rf "${JUNEST_HOME:?}"/*
    # shellcheck disable=SC2317
    wget_mock(){
        # Proof that the setup is happening
        # inside $JUNEST_TEMPDIR
        local cwd=${PWD#"${JUNEST_TEMPDIR}"}
        local parent_dir=${PWD%"${cwd}"}
        assertEquals "$JUNEST_TEMPDIR" "${parent_dir}"
        touch file
        tar -czvf "${CMD}-${ARCH}".tar.gz file
    }
    # shellcheck disable=SC2034
    WGET=wget_mock
    # shellcheck disable=SC2119
    setup_env 1> /dev/null
    assertTrue "[ -e $JUNEST_HOME/file ]"

    assertCommandFailOnStatus 102 setup_env "noarch"
}


function test_setup_env_from_file(){
    rm -rf "${JUNEST_HOME:?}"/*
    touch file
    tar -czvf "${CMD}-${ARCH}".tar.gz file 1> /dev/null
    assertCommandSuccess setup_env_from_file "${CMD}-${ARCH}.tar.gz"
    assertTrue "[ -e $JUNEST_HOME/file ]"
}

function test_setup_env_from_file_not_existing_file(){
    assertCommandFailOnStatus 103 setup_env_from_file noexist.tar.gz
}

function test_setup_env_from_file_with_absolute_path(){
    rm -rf "${JUNEST_HOME:?}"/*
    touch file
    tar -czf "${CMD}-${ARCH}".tar.gz file
    assertCommandSuccess setup_env_from_file "${CMD}-${ARCH}.tar.gz"
    assertTrue "[ -e $JUNEST_HOME/file ]"
}

function test_delete_env(){
    echo "N" | delete_env 1> /dev/null
    assertCommandSuccess is_env_installed
    echo "Y" | delete_env 1> /dev/null
    assertCommandFail is_env_installed
}

source "$JUNEST_ROOT"/tests/utils/shunit2
