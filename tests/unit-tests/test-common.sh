#!/bin/bash

JUNEST_ROOT=$(readlink -f $(dirname $0)/../..)

source "$JUNEST_ROOT/tests/utils/utils.sh"

source "$JUNEST_ROOT/lib/utils/utils.sh"
source "$JUNEST_ROOT/lib/core/common.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
    junestSetUp
}

function oneTimeTearDown(){
    junestTearDown
}

function setUp(){
    ld_exec() {
        echo "ld_exec $@"
    }
    LD_EXEC=ld_exec
}

function test_ln(){
    LN=echo assertCommandSuccess ln_cmd -s ln_file new_file
    assertEquals "-s ln_file new_file" "$(cat $STDOUTF)"

    LN=false assertCommandSuccess ln_cmd -s ln_file new_file
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false -s ln_file new_file" "$(cat $STDOUTF)"

    LN=false LD_EXEC=false assertCommandFail ln_cmd
}

function test_getent(){
    GETENT=echo assertCommandSuccess getent_cmd passwd
    assertEquals "passwd" "$(cat $STDOUTF)"

    GETENT=false assertCommandSuccess getent_cmd passwd
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false passwd" "$(cat $STDOUTF)"

    GETENT=false LD_EXEC=false assertCommandFail getent_cmd
}

function test_cp(){
    CP=echo assertCommandSuccess cp_cmd passwd
    assertEquals "passwd" "$(cat $STDOUTF)"

    CP=false assertCommandSuccess cp_cmd passwd
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false passwd" "$(cat $STDOUTF)"

    CP=false LD_EXEC=false assertCommandFail cp_cmd
}

function test_download(){
    WGET=/bin/true
    CURL=/bin/false
    assertCommandSuccess download_cmd

    WGET=/bin/false
    CURL=/bin/true
    assertCommandSuccess download_cmd

    WGET=/bin/false CURL=/bin/false assertCommandFail download_cmd
}

function test_rm(){
    RM=echo assertCommandSuccess rm_cmd rm_file
    assertEquals "rm_file" "$(cat $STDOUTF)"

    RM=false assertCommandSuccess rm_cmd rm_file
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false rm_file" "$(cat $STDOUTF)"

    RM=false LD_EXEC=false assertCommandFail rm_cmd rm_file
}

function test_chown(){
    local id=$(id -u)

    CHOWN=echo assertCommandSuccess chown_cmd $id chown_file
    assertEquals "$id chown_file" "$(cat $STDOUTF)"

    CHOWN=false assertCommandSuccess chown_cmd $id chown_file
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false $id chown_file" "$(cat $STDOUTF)"

    CHOWN=false LD_EXEC=false assertCommandFail chown_cmd $id chown_file
}

function test_mkdir(){
    MKDIR=echo assertCommandSuccess mkdir_cmd -p new_dir/new_dir
    assertEquals "-p new_dir/new_dir" "$(cat $STDOUTF)"

    MKDIR=false assertCommandSuccess mkdir_cmd -p new_dir/new_dir
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false -p new_dir/new_dir" "$(cat $STDOUTF)"

    MKDIR=false LD_EXEC=false assertCommandFail mkdir_cmd -p new_dir/new_dir
}

function test_zgrep(){
    ZGREP=echo assertCommandSuccess zgrep_cmd new_file
    assertEquals "new_file" "$(cat $STDOUTF)"

    ZGREP=false assertCommandSuccess zgrep_cmd new_file
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false new_file" "$(cat $STDOUTF)"

    ZGREP=false LD_EXEC=false assertCommandFail zgrep_cmd new_file
}

function test_unshare(){
    UNSHARE=echo assertCommandSuccess unshare_cmd new_program
    assertEquals "new_program" "$(cat $STDOUTF)"

    UNSHARE=false assertCommandSuccess unshare_cmd new_program
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false new_program" "$(cat $STDOUTF)"

    UNSHARE=false LD_EXEC=false assertCommandFail unshare_cmd new_program
}

function test_chroot(){
    JCHROOT=echo assertCommandSuccess chroot_cmd root
    assertEquals "root" "$(cat $STDOUTF)"

    JCHROOT=false CLASSIC_CHROOT=echo assertCommandSuccess chroot_cmd root
    assertEquals "root" "$(cat $STDOUTF)"

    JCHROOT=false CLASSIC_CHROOT=false assertCommandSuccess chroot_cmd root
    assertEquals "ld_exec $JUNEST_HOME/usr/bin/false root" "$(cat $STDOUTF)"

    JCHROOT=false CLASSIC_CHROOT=false LD_EXEC=false assertCommandFail chroot_cmd root
}

function test_proot_cmd_compat(){
    PROOT="/bin/true" assertCommandSuccess proot_cmd "" ""

    PROOT="/bin/false" assertCommandFail proot_cmd --helps
}

function test_proot_cmd_seccomp(){
    envv(){
        env
    }
    PROOT=envv
    assertCommandSuccess proot_cmd cmd
    assertEquals "" "$(cat $STDOUTF | grep "^PROOT_NO_SECCOMP")"

    envv(){
        env | grep "^PROOT_NO_SECCOMP"
    }
    PROOT=envv
    local output=$(proot_cmd | grep "^PROOT_NO_SECCOMP")
    assertCommandSuccess proot_cmd cmd
    # The variable PROOT_NO_SECCOMP will be produced
    # twice due to the fallback mechanism
    assertEquals "PROOT_NO_SECCOMP=1
PROOT_NO_SECCOMP=1" "$(cat $STDOUTF | grep "^PROOT_NO_SECCOMP")"
}

function test_copy_passwd_and_group(){
    getent_cmd_mock() {
        echo $@
    }
    GETENT=getent_cmd_mock assertCommandSuccess copy_passwd_and_group
    assertEquals "$(echo -e "passwd\npasswd $USER")" "$(cat $JUNEST_HOME/etc/passwd)"
    assertEquals "group" "$(cat $JUNEST_HOME/etc/group)"
}

function test_copy_passwd_and_group_fallback(){
    cp_cmd_mock() {
        echo $@
    }
    CP=cp_cmd_mock GETENT=false LD_EXEC=false assertCommandSuccess copy_passwd_and_group
    assertEquals "$(echo -e "/etc/passwd $JUNEST_HOME//etc/passwd\n/etc/group $JUNEST_HOME//etc/group")" "$(cat $STDOUTF)"
}

function test_copy_passwd_and_group_failure(){
    CP=false GETENT=false LD_EXEC=false assertCommandFailOnStatus 1 copy_passwd_and_group
}

function test_nested_env(){
    JUNEST_ENV=1 assertCommandFailOnStatus 106 bash -c "source $JUNEST_ROOT/lib/utils/utils.sh; source $JUNEST_ROOT/lib/core/common.sh"
}

function test_nested_env_not_set_variable(){
    JUNEST_ENV=aaa assertCommandFailOnStatus 107 bash -c "source $JUNEST_ROOT/lib/utils/utils.sh; source $JUNEST_ROOT/lib/core/common.sh"
}

source $JUNEST_ROOT/tests/utils/shunit2
