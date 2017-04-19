#!/bin/bash

JUNEST_ROOT=$(readlink -f $(dirname $0)/../..)

source "$JUNEST_ROOT/tests/utils/utils.sh"

source "$JUNEST_ROOT/lib/utils/utils.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

## Mock functions ##
function init_mocks() {
    function unshare_cmd(){
        echo "unshare $@"
    }
}

function setUp(){
    cwdSetUp
    junestSetUp

    # Attempt to source the files under test to revert variable
    # overrides (i.e. SH variable)
    source "$JUNEST_ROOT/lib/core/common.sh"
    source "$JUNEST_ROOT/lib/core/namespace.sh"
    set +e

    init_mocks
}

function tearDown(){
    junestTearDown
    cwdTearDown
}

function _test_copy_common_files() {
    [[ -e /etc/hosts ]] && assertEquals "$(cat /etc/hosts)" "$(cat ${JUNEST_HOME}/etc/hosts)"
    [[ -e /etc/host.conf ]] && assertEquals "$(cat /etc/host.conf)" "$(cat ${JUNEST_HOME}/etc/host.conf)"
    [[ -e /etc/nsswitch.conf ]] && assertEquals "$(cat /etc/nsswitch.conf)" "$(cat ${JUNEST_HOME}/etc/nsswitch.conf)"
    [[ -e /etc/resolv.conf ]] && assertEquals "$(cat /etc/resolv.conf)" "$(cat ${JUNEST_HOME}/etc/resolv.conf)"
}

function _test_copy_remaining_files() {
    [[ -e /etc/hosts.equiv ]] && assertEquals "$(cat /etc/hosts.equiv)" "$(cat ${JUNEST_HOME}/etc/hosts.equiv)"
    [[ -e /etc/netgroup ]] && assertEquals "$(cat /etc/netgroup)" "$(cat ${JUNEST_HOME}/etc/netgroup)"
    [[ -e /etc/networks ]] && assertEquals "$(cat /etc/networks)" "$(cat ${JUNEST_HOME}/etc/networks)"

    [[ -e ${JUNEST_HOME}/etc/passwd ]]
    assertEquals 0 $?
    [[ -e ${JUNEST_HOME}/etc/group ]]
    assertEquals 0 $?
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

function test_run_env_with_namespace() {
    assertCommandSuccess run_env_with_namespace "" ""
    assertEquals "unshare --mount --user --map-root-user $GROOT --no-umount --recursive -b $HOME -b /tmp -b /proc -b /sys -b /dev $JUNEST_HOME /bin/sh --login" "$(cat $STDOUTF)"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_with_namespace_with_bindings() {
    assertCommandSuccess run_env_with_namespace "-b /usr -b /lib:/tmp/lib" ""
    assertEquals "unshare --mount --user --map-root-user $GROOT --no-umount --recursive -b $HOME -b /tmp -b /proc -b /sys -b /dev -b /usr -b /lib:/tmp/lib $JUNEST_HOME /bin/sh --login" "$(cat $STDOUTF)"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_with_namespace_with_command() {
    assertCommandSuccess run_env_with_namespace "" "ls -la"
    assertEquals "unshare --mount --user --map-root-user $GROOT --no-umount --recursive -b $HOME -b /tmp -b /proc -b /sys -b /dev $JUNEST_HOME /bin/sh --login -c \"ls -la\"" "$(cat $STDOUTF)"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_with_namespace_with_bindings_and_command() {
    assertCommandSuccess run_env_with_namespace "-b /usr -b /lib:/tmp/lib" "ls -la"
    assertEquals "unshare --mount --user --map-root-user $GROOT --no-umount --recursive -b $HOME -b /tmp -b /proc -b /sys -b /dev -b /usr -b /lib:/tmp/lib $JUNEST_HOME /bin/sh --login -c \"ls -la\"" "$(cat $STDOUTF)"

    _test_copy_common_files
    _test_copy_remaining_files
}

source $JUNEST_ROOT/tests/utils/shunit2
