#!/bin/bash

JUNEST_ROOT=$(readlink -f $(dirname $0)/../..)

source "$JUNEST_ROOT/tests/utils/utils.sh"

source "$JUNEST_ROOT/lib/utils/utils.sh"
source "$JUNEST_ROOT/lib/core/common.sh"
source "$JUNEST_ROOT/lib/core/namespace.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function setUp(){
    cwdSetUp
}

function tearDown(){
    cwdTearDown
}

function test_is_user_namespace_enabled_no_config_file(){
    CONFIG_PROC_FILE="blah"
    CONFIG_BOOT_FILE="blah"
    assertCommandFailOnStatus $NOT_EXISTING_FILE _is_user_namespace_enabled
}

function test_is_user_namespace_enabled_no_config(){
    touch config
    gzip config
    CONFIG_PROC_FILE="config.gz"
    CONFIG_BOOT_FILE="blah"
    assertCommandFailOnStatus $NO_CONFIG_FOUND _is_user_namespace_enabled
}

function test_is_user_namespace_enabled_with_config(){
    echo "CONFIG_USER_NS=y" > config
    gzip config
    CONFIG_PROC_FILE="config.gz"
    CONFIG_BOOT_FILE="blah"
    assertCommandSuccess _is_user_namespace_enabled
}

source $JUNEST_ROOT/tests/utils/shunit2
