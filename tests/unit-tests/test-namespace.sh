#!/bin/bash
# shellcheck disable=SC1091

JUNEST_ROOT=$(readlink -f "$(dirname "$0")"/../..)

source "$JUNEST_ROOT/tests/utils/utils.sh"

source "$JUNEST_ROOT/lib/utils/utils.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

## Mock functions ##
function init_mocks() {
    # shellcheck disable=SC2317
    function bwrap_cmd(){
        echo "$BWRAP $*"
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
    [[ -e /etc/hosts ]] && assertEquals "$(cat /etc/hosts)" "$(cat "${JUNEST_HOME}"/etc/hosts)"
    [[ -e /etc/host.conf ]] && assertEquals "$(cat /etc/host.conf)" "$(cat "${JUNEST_HOME}"/etc/host.conf)"
    [[ -e /etc/nsswitch.conf ]] && assertEquals "$(cat /etc/nsswitch.conf)" "$(cat "${JUNEST_HOME}"/etc/nsswitch.conf)"
    [[ -e /etc/resolv.conf ]] && assertEquals "$(cat /etc/resolv.conf)" "$(cat "${JUNEST_HOME}"/etc/resolv.conf)"
}

function _test_copy_remaining_files() {
    [[ -e /etc/hosts.equiv ]] && assertEquals "$(cat /etc/hosts.equiv)" "$(cat "${JUNEST_HOME}"/etc/hosts.equiv)"
    [[ -e /etc/netgroup ]] && assertEquals "$(cat /etc/netgroup)" "$(cat "${JUNEST_HOME}"/etc/netgroup)"
    [[ -e /etc/networks ]] && assertEquals "$(cat /etc/networks)" "$(cat "${JUNEST_HOME}"/etc/networks)"

    [[ -e ${JUNEST_HOME}/etc/passwd ]]
    assertEquals 0 $?
    [[ -e ${JUNEST_HOME}/etc/group ]]
    assertEquals 0 $?
}

function test_is_user_namespace_enabled_no_config_file(){
    PROC_USERNS_FILE="blah"
    PROC_USERNS_CLONE_FILE="blah"
    CONFIG_PROC_FILE="blah"
    CONFIG_BOOT_FILE="blah"
    assertCommandFailOnStatus "$NOT_EXISTING_FILE" _is_user_namespace_enabled
}

function test_is_user_namespace_enabled_no_config(){
    PROC_USERNS_FILE="blah"
    PROC_USERNS_CLONE_FILE="blah"
    touch config
    gzip config
    # shellcheck disable=SC2034
    CONFIG_PROC_FILE="config.gz"
    # shellcheck disable=SC2034
    CONFIG_BOOT_FILE="blah"
    assertCommandFailOnStatus "$NO_CONFIG_FOUND" _is_user_namespace_enabled
}

function test_is_user_namespace_enabled_with_userns_clone_file_disabled(){
    PROC_USERNS_FILE="blah"
    PROC_USERNS_CLONE_FILE="unprivileged_userns_clone"
    echo "0" > $PROC_USERNS_CLONE_FILE
    assertCommandFailOnStatus "$UNPRIVILEGED_USERNS_DISABLED" _is_user_namespace_enabled
}

function test_is_user_namespace_enabled_with_userns_clone_file_enabled(){
    PROC_USERNS_CLONE_FILE="unprivileged_userns_clone"
    echo "1" > $PROC_USERNS_CLONE_FILE
    assertCommandSuccess _is_user_namespace_enabled
}

function test_is_user_namespace_enabled_with_proc_userns_file_existing(){
    PROC_USERNS_FILE="user"
    ln -s . $PROC_USERNS_FILE
    PROC_USERNS_CLONE_FILE="blah"
    assertCommandSuccess _is_user_namespace_enabled
}

function test_run_env_as_bwrap_fakeroot() {
    assertCommandSuccess run_env_as_bwrap_fakeroot "" "" "false"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION --cap-add ALL --uid 0 --gid 0 sudo /bin/sh --login" "$(cat "$STDOUTF")"

    _test_copy_common_files
}

function test_run_env_as_bwrap_fakeroot_with_backend_command() {
    assertCommandSuccess run_env_as_bwrap_fakeroot "mybwrap" "" "false"
    assertEquals "mybwrap $COMMON_BWRAP_OPTION --cap-add ALL --uid 0 --gid 0 sudo /bin/sh --login" "$(cat "$STDOUTF")"

    _test_copy_common_files
}

function test_run_env_as_bwrap_user() {
    assertCommandSuccess run_env_as_bwrap_user "" "" "false"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION /bin/sh --login" "$(cat "$STDOUTF")"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_as_bwrap_user_with_backend_command() {
    assertCommandSuccess run_env_as_bwrap_user "mybwrap" "" "false"
    assertEquals "mybwrap $COMMON_BWRAP_OPTION /bin/sh --login" "$(cat "$STDOUTF")"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_as_bwrap_fakeroot_no_copy() {
    assertCommandSuccess run_env_as_bwrap_fakeroot "" "" "true" ""
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION --cap-add ALL --uid 0 --gid 0 sudo /bin/sh --login" "$(cat "$STDOUTF")"

    [[ ! -e ${JUNEST_HOME}/etc/hosts ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/host.conf ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/nsswitch.conf ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/resolv.conf ]]
    assertEquals 0 $?

    [[ ! -e ${JUNEST_HOME}/etc/hosts.equiv ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/netgroup ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/networks ]]
    assertEquals 0 $?

    [[ ! -e ${JUNEST_HOME}/etc/passwd ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/group ]]
    assertEquals 0 $?
}

function test_run_env_as_bwrap_user_no_copy() {
    assertCommandSuccess run_env_as_bwrap_user "" "" "true" ""
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION /bin/sh --login" "$(cat "$STDOUTF")"

    [[ ! -e ${JUNEST_HOME}/etc/hosts ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/host.conf ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/nsswitch.conf ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/resolv.conf ]]
    assertEquals 0 $?

    [[ ! -e ${JUNEST_HOME}/etc/hosts.equiv ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/netgroup ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/networks ]]
    assertEquals 0 $?

    [[ ! -e ${JUNEST_HOME}/etc/passwd ]]
    assertEquals 0 $?
    [[ ! -e ${JUNEST_HOME}/etc/group ]]
    assertEquals 0 $?
}

function test_run_env_as_bwrap_fakeroot_with_backend_args() {
    assertCommandSuccess run_env_as_bwrap_fakeroot "" "--bind /usr /usr" "false"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION --cap-add ALL --uid 0 --gid 0 --bind /usr /usr sudo /bin/sh --login" "$(cat "$STDOUTF")"

    _test_copy_common_files
}

function test_run_env_as_bwrap_user_with_backend_args() {
    assertCommandSuccess run_env_as_bwrap_user "" "--bind /usr /usr" "false"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION --bind /usr /usr /bin/sh --login" "$(cat "$STDOUTF")"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_as_bwrap_fakeroot_with_command() {
    assertCommandSuccess run_env_as_bwrap_fakeroot "" "" "false" "ls -la"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION --cap-add ALL --uid 0 --gid 0 sudo /bin/sh --login -c \"ls -la\"" "$(cat "$STDOUTF")"

    _test_copy_common_files
}

function test_run_env_as_bwrap_user_with_command() {
    assertCommandSuccess run_env_as_bwrap_user "" "" "false" "ls -la"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION /bin/sh --login -c \"ls -la\"" "$(cat "$STDOUTF")"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_as_bwrap_fakeroot_with_backend_args_and_command() {
    assertCommandSuccess run_env_as_bwrap_fakeroot "" "--bind /usr /usr" "false" "ls -la"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION --cap-add ALL --uid 0 --gid 0 --bind /usr /usr sudo /bin/sh --login -c \"ls -la\"" "$(cat "$STDOUTF")"

    _test_copy_common_files
}

function test_run_env_as_bwrap_user_with_backend_args_and_command() {
    assertCommandSuccess run_env_as_bwrap_user "" "--bind /usr /usr" "false" "ls -la"
    assertEquals "$BWRAP $COMMON_BWRAP_OPTION --bind /usr /usr /bin/sh --login -c \"ls -la\"" "$(cat "$STDOUTF")"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_as_bwrap_fakeroot_nested_env(){
    JUNEST_ENV=1
    assertCommandFailOnStatus 106 run_env_as_bwrap_fakeroot "" "" "false" ""
    unset JUNEST_ENV
}

function test_run_env_as_bwrap_user_nested_env(){
    # shellcheck disable=SC2034
    JUNEST_ENV=1
    assertCommandFailOnStatus 106 run_env_as_bwrap_user "" "" "false" ""
    unset JUNEST_ENV
}

source "$JUNEST_ROOT"/tests/utils/shunit2
