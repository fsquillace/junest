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

function setUp(){
    cwdSetUp
    junestSetUp

    # Attempt to source the files under test to revert variable
    # overrides (i.e. SH variable)
    source "$JUNEST_ROOT/lib/core/common.sh"
    source "$JUNEST_ROOT/lib/core/proot.sh"
    set +e
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

function test_run_env_as_proot_user(){
    # shellcheck disable=SC2317
    _run_env_with_qemu() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    assertCommandSuccess run_env_as_proot_user "" "-k 3.10" "false" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "-b /run/user/$(id -u) -b $HOME -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat "$STDOUTF")"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_proot_user "" "-k 3.10" "false"
    assertEquals "-b /run/user/$(id -u) -b $HOME -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10" "$(cat "$STDOUTF")"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_as_proot_user_with_backend_command(){
    # shellcheck disable=SC2317
    _run_env_with_qemu() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    assertCommandSuccess run_env_as_proot_user "myproot" "-k 3.10" "false" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "myproot -b /run/user/$(id -u) -b $HOME -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat "$STDOUTF")"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_proot_user "myproot" "-k 3.10" "false"
    assertEquals "myproot -b /run/user/$(id -u) -b $HOME -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10" "$(cat "$STDOUTF")"

    _test_copy_common_files
    _test_copy_remaining_files
}

function test_run_env_as_proot_user_no_copy(){
    # shellcheck disable=SC2317
    _run_env_with_qemu() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    assertCommandSuccess run_env_as_proot_user "" "-k 3.10" "true" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "-b /run/user/$(id -u) -b $HOME -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat "$STDOUTF")"

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

function test_run_env_as_proot_user_nested_env(){
    JUNEST_ENV=1
    assertCommandFailOnStatus 106 run_env_as_proot_user "" "" "false"
    unset JUNEST_ENV
}

function test_run_env_as_proot_fakeroot(){
    # shellcheck disable=SC2317
    _run_env_with_qemu() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    assertCommandSuccess run_env_as_proot_fakeroot "" "-k 3.10" "false" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "-0 -b /run/user/$(id -u) -b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat "$STDOUTF")"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_proot_fakeroot "" "-k 3.10" "false"
    assertEquals "-0 -b /run/user/$(id -u) -b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10" "$(cat "$STDOUTF")"

    _test_copy_common_files
}

function test_run_env_as_proot_fakeroot_with_backend_command(){
    # shellcheck disable=SC2317
    _run_env_with_qemu() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    assertCommandSuccess run_env_as_proot_fakeroot "myproot" "-k 3.10" "false" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "myproot -0 -b /run/user/$(id -u) -b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2034
    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_proot_fakeroot "myproot" "-k 3.10" "false"
    assertEquals "myproot -0 -b /run/user/$(id -u) -b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10" "$(cat "$STDOUTF")"

    _test_copy_common_files
}

function test_run_env_as_proot_fakeroot_nested_env(){
    JUNEST_ENV=1
    assertCommandFailOnStatus 106 run_env_as_proot_fakeroot "" "" "false" ""
    unset JUNEST_ENV
}

function test_run_env_with_quotes(){
    # shellcheck disable=SC2317
    _run_env_with_qemu() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    assertCommandSuccess run_env_as_proot_user "" "-k 3.10" "false" "bash" "-c" "/usr/bin/mkdir -v /newdir2"
    assertEquals "-b /run/user/$(id -u) -b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 bash -c /usr/bin/mkdir -v /newdir2" "$(cat "$STDOUTF")"
}

function test_run_env_with_proot_args(){
    # shellcheck disable=SC2317
    proot_cmd() {
        [ "$JUNEST_ENV" != "1" ] && return 1
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }

    assertCommandSuccess _run_env_with_proot "" "--help"
    assertEquals "--help /bin/sh --login" "$(cat "$STDOUTF")"

    assertCommandSuccess _run_env_with_proot "" "--help" mycommand
    assertEquals "--help /bin/sh --login -c mycommand" "$(cat "$STDOUTF")"

    assertCommandFail _run_env_with_proot
}

function test_qemu() {
    echo "JUNEST_ARCH=arm" > "${JUNEST_HOME}"/etc/junest/info
    # shellcheck disable=SC2317
    rm_cmd() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    # shellcheck disable=SC2317
    ln_cmd() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }
    # shellcheck disable=SC2317
    _run_env_with_proot() {
        # shellcheck disable=SC2086
        # shellcheck disable=SC2048
        echo $*
    }

    RANDOM=100 ARCH=x86_64 assertCommandSuccess _run_env_with_qemu "" ""
    assertEquals "$(echo -e "-s $JUNEST_HOME/bin/qemu-arm-static-x86_64 /tmp/qemu-arm-static-x86_64-100\n-q /tmp/qemu-arm-static-x86_64-100")" "$(cat "$STDOUTF")"
}

source "$JUNEST_ROOT"/tests/utils/shunit2
