#!/bin/bash

JUNEST_ROOT=$(readlink -f $(dirname $0)/../..)

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

function test_run_env_as_user(){
    _run_env_with_qemu() {
        echo $@
    }
    assertCommandSuccess run_env_as_user "-k 3.10" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "-b $HOME -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat $STDOUTF)"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_user "-k 3.10"
    assertEquals "-b $HOME -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10" "$(cat $STDOUTF)"

    [[ -e /etc/hosts ]] && assertEquals "$(cat /etc/hosts)" "$(cat ${JUNEST_HOME}/etc/hosts)"
    [[ -e /etc/host.conf ]] && assertEquals "$(cat /etc/host.conf)" "$(cat ${JUNEST_HOME}/etc/host.conf)"
    [[ -e /etc/nsswitch.conf ]] && assertEquals "$(cat /etc/nsswitch.conf)" "$(cat ${JUNEST_HOME}/etc/nsswitch.conf)"
    [[ -e /etc/resolv.conf ]] && assertEquals "$(cat /etc/resolv.conf)" "$(cat ${JUNEST_HOME}/etc/resolv.conf)"

    [[ -e /etc/hosts.equiv ]] && assertEquals "$(cat /etc/hosts.equiv)" "$(cat ${JUNEST_HOME}/etc/hosts.equiv)"
    [[ -e /etc/netgroup ]] && assertEquals "$(cat /etc/netgroup)" "$(cat ${JUNEST_HOME}/etc/netgroup)"

    [[ -e /etc/passwd ]]
    assertEquals 0 $?
    [[ -e /etc/group ]]
    assertEquals 0 $?

}

function test_run_env_as_fakeroot(){
    _run_env_with_qemu() {
        echo $@
    }
    assertCommandSuccess run_env_as_fakeroot "-k 3.10" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "-0 -b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat $STDOUTF)"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_fakeroot "-k 3.10"
    assertEquals "-0 -b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10" "$(cat $STDOUTF)"

    [[ -e /etc/hosts ]] && assertEquals "$(cat /etc/hosts)" "$(cat ${JUNEST_HOME}/etc/hosts)"
    [[ -e /etc/host.conf ]] && assertEquals "$(cat /etc/host.conf)" "$(cat ${JUNEST_HOME}/etc/host.conf)"
    [[ -e /etc/nsswitch.conf ]] && assertEquals "$(cat /etc/nsswitch.conf)" "$(cat ${JUNEST_HOME}/etc/nsswitch.conf)"
    [[ -e /etc/resolv.conf ]] && assertEquals "$(cat /etc/resolv.conf)" "$(cat ${JUNEST_HOME}/etc/resolv.conf)"
}

function test_run_env_with_quotes(){
    _run_env_with_qemu() {
        echo $@
    }
    assertCommandSuccess run_env_as_user "-k 3.10" "bash" "-c" "/usr/bin/mkdir -v /newdir2"
    assertEquals "-b ${HOME} -b /tmp -b /proc -b /sys -b /dev -r ${JUNEST_HOME} -k 3.10 bash -c /usr/bin/mkdir -v /newdir2" "$(cat $STDOUTF)"
}

function test_run_env_with_proot_args(){
    proot_cmd() {
        [ "$JUNEST_ENV" != "1" ] && return 1
        echo $@
    }

    assertCommandSuccess _run_env_with_proot --help
    assertEquals "--help /bin/sh --login" "$(cat $STDOUTF)"

    assertCommandSuccess _run_env_with_proot --help mycommand
    assertEquals "--help /bin/sh --login -c mycommand" "$(cat $STDOUTF)"

    assertCommandFail _run_env_with_proot
}

function test_qemu() {
    echo "JUNEST_ARCH=arm" > ${JUNEST_HOME}/etc/junest/info
    rm_cmd() {
        echo $@
    }
    ln_cmd() {
        echo $@
    }
    _run_env_with_proot() {
        echo $@
    }

    RANDOM=100 ARCH=x86_64 assertCommandSuccess _run_env_with_qemu ""
    assertEquals "$(echo -e "-s $JUNEST_HOME/opt/qemu/qemu-arm-static-x86_64 /tmp/qemu-arm-static-x86_64-100\n-q /tmp/qemu-arm-static-x86_64-100")" "$(cat $STDOUTF)"
}

source $JUNEST_ROOT/tests/utils/shunit2
