#!/bin/bash
# shellcheck disable=SC1091

JUNEST_ROOT=$(readlink -f "$(dirname "$0")"/../..)

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
    ld_exec_mock() {
        # shellcheck disable=SC2317
        echo "ld_exec $*"
    }
    # shellcheck disable=SC2317
    ld_exec_mock_false() {
        echo "ld_exec $*"
        return 1
    }
    # shellcheck disable=SC2034
    LD_EXEC=ld_exec_mock

    unshare_mock() {
        # shellcheck disable=SC2317
        echo "unshare $*"
    }
    # shellcheck disable=SC2034
    UNSHARE=unshare_mock

    # shellcheck disable=SC2317
    bwrap_mock() {
        echo "bwrap $*"
    }
    # shellcheck disable=SC2034
    BWRAP=bwrap_mock

}

function test_ln(){
    LN="echo" assertCommandSuccess ln_cmd -s ln_file new_file
    assertEquals "-s ln_file new_file" "$(cat "$STDOUTF")"

    LN=false assertCommandSuccess ln_cmd -s ln_file new_file
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false -s ln_file new_file" "$(cat "$STDOUTF")"

    LN=false LD_EXEC=false assertCommandFail ln_cmd
}

function test_getent(){
    GETENT="echo" assertCommandSuccess getent_cmd passwd
    assertEquals "passwd" "$(cat "$STDOUTF")"

    GETENT="false" assertCommandSuccess getent_cmd passwd
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false passwd" "$(cat "$STDOUTF")"

    GETENT=false LD_EXEC=false assertCommandFail getent_cmd
}

function test_cp(){
    CP="echo" assertCommandSuccess cp_cmd passwd
    assertEquals "passwd" "$(cat "$STDOUTF")"

    CP=false assertCommandSuccess cp_cmd passwd
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false passwd" "$(cat "$STDOUTF")"

    CP=false LD_EXEC=false assertCommandFail cp_cmd
}

function test_download(){
    WGET=/bin/true
    CURL=/bin/false
    assertCommandSuccess download_cmd

    # shellcheck disable=SC2034
    WGET=/bin/false
    # shellcheck disable=SC2034
    CURL=/bin/true
    assertCommandSuccess download_cmd

    WGET=/bin/false CURL=/bin/false assertCommandFail download_cmd
}

function test_rm(){
    RM="echo" assertCommandSuccess rm_cmd rm_file
    assertEquals "rm_file" "$(cat "$STDOUTF")"

    RM="false" assertCommandSuccess rm_cmd rm_file
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false rm_file" "$(cat "$STDOUTF")"

    RM=false LD_EXEC=false assertCommandFail rm_cmd rm_file
}

function test_chown(){
    local id
    id=$(id -u)

    CHOWN="echo" assertCommandSuccess chown_cmd "$id" chown_file
    assertEquals "$id chown_file" "$(cat "$STDOUTF")"

    CHOWN="false" assertCommandSuccess chown_cmd "$id" chown_file
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false $id chown_file" "$(cat "$STDOUTF")"

    CHOWN=false LD_EXEC=false assertCommandFail chown_cmd "$id" chown_file
}

function test_mkdir(){
    MKDIR="echo" assertCommandSuccess mkdir_cmd -p new_dir/new_dir
    assertEquals "-p new_dir/new_dir" "$(cat "$STDOUTF")"

    MKDIR=false assertCommandSuccess mkdir_cmd -p new_dir/new_dir
    assertEquals "ld_exec ${JUNEST_HOME}/usr/bin/false -p new_dir/new_dir" "$(cat "$STDOUTF")"

    MKDIR=false LD_EXEC=false assertCommandFail mkdir_cmd -p new_dir/new_dir
}

function test_zgrep(){
    ZGREP="echo" assertCommandSuccess zgrep_cmd new_file
    assertEquals "new_file" "$(cat "$STDOUTF")"

    mkdir -p "${JUNEST_HOME}"/usr/bin
    touch "${JUNEST_HOME}"/usr/bin/false
    chmod +x "${JUNEST_HOME}"/usr/bin/false

    echo -e "#!/bin/bash\necho zgrep" > "${JUNEST_HOME}"/usr/bin/false
    ZGREP=false assertCommandSuccess zgrep_cmd new_file
    assertEquals "zgrep" "$(cat "$STDOUTF")"

    echo -e "#!/bin/bash\nexit 1" > "${JUNEST_HOME}"/usr/bin/false
    ZGREP=false assertCommandFail zgrep_cmd new_file
}

function test_unshare(){
    assertCommandSuccess unshare_cmd new_program
    assertEquals "$(echo -e "ld_exec ${JUNEST_HOME}/usr/bin/$UNSHARE --user /bin/sh -c :\nld_exec ${JUNEST_HOME}/usr/bin/$UNSHARE new_program")" "$(cat "$STDOUTF")"

    LD_EXEC=ld_exec_mock_false assertCommandSuccess unshare_cmd new_program
    assertEquals "$(echo -e "ld_exec ${JUNEST_HOME}/usr/bin/unshare_mock --user /bin/sh -c :\nunshare --user /bin/sh -c :\nunshare new_program")" "$(cat "$STDOUTF")"

    UNSHARE=false LD_EXEC=false assertCommandFail unshare_cmd new_program
}

function test_bwrap(){
    assertCommandSuccess bwrap_cmd new_program
    assertEquals "$(echo -e "ld_exec $BWRAP --dev-bind / / /bin/sh -c :\nld_exec $BWRAP new_program")" "$(cat "$STDOUTF")"

    BWRAP=false LD_EXEC=false assertCommandFail bwrap_cmd new_program
}

function test_chroot(){
    CLASSIC_CHROOT="echo" assertCommandSuccess chroot_cmd root
    assertEquals "root" "$(cat "$STDOUTF")"

    CLASSIC_CHROOT=false assertCommandSuccess chroot_cmd root
    assertEquals "ld_exec $JUNEST_HOME/usr/bin/false root" "$(cat "$STDOUTF")"

    CLASSIC_CHROOT=false LD_EXEC=false assertCommandFail chroot_cmd root
}

function test_proot_cmd_compat(){
    PROOT="/bin/true" assertCommandSuccess proot_cmd "" ""

    PROOT="/bin/false" assertCommandFail proot_cmd --helps
}

function test_proot_cmd_seccomp(){
    envv(){
        # shellcheck disable=SC2317
        env
    }
    PROOT=envv
    assertCommandSuccess proot_cmd cmd
    assertEquals "" "$(grep "^PROOT_NO_SECCOMP" "$STDOUTF")"

    envv(){
        # shellcheck disable=SC2317
        env | grep "^PROOT_NO_SECCOMP"
    }
    # shellcheck disable=SC2034
    PROOT=envv
    assertCommandSuccess proot_cmd cmd
    # The variable PROOT_NO_SECCOMP will be produced
    # twice due to the fallback mechanism
    assertEquals "PROOT_NO_SECCOMP=1
PROOT_NO_SECCOMP=1" "$(grep "^PROOT_NO_SECCOMP" "$STDOUTF")"
}

function test_copy_passwd_and_group(){
    getent_cmd_mock() {
        # shellcheck disable=SC2317
        echo "$*"
    }
    GETENT=getent_cmd_mock assertCommandSuccess copy_passwd_and_group
    assertEquals "$(echo -e "passwd\npasswd $USER")" "$(cat "$JUNEST_HOME"/etc/passwd)"
    assertEquals "group" "$(cat "$JUNEST_HOME"/etc/group)"
}

function test_copy_passwd_and_group_fallback(){
    cp_cmd_mock() {
        # shellcheck disable=SC2317
        echo "$*"
    }
    CP=cp_cmd_mock GETENT=false LD_EXEC=false assertCommandSuccess copy_passwd_and_group
    assertEquals "$(echo -e "-f /etc/passwd $JUNEST_HOME//etc/passwd\n-f /etc/group $JUNEST_HOME//etc/group")" "$(cat "$STDOUTF")"
}

function test_copy_passwd_and_group_failure(){
    CP=false GETENT=false LD_EXEC=false assertCommandFailOnStatus 1 copy_passwd_and_group
}

function test_nested_env(){
    JUNEST_ENV=1 assertCommandFailOnStatus 106 check_nested_env
}

function test_nested_env_not_set_variable(){
    JUNEST_ENV=aaa assertCommandFailOnStatus 107 check_nested_env
}

function test_check_same_arch_not_same(){
    echo "JUNEST_ARCH=XXX" > "${JUNEST_HOME}"/etc/junest/info
    assertCommandFailOnStatus 104 check_same_arch
}

function test_check_same_arch(){
    echo "JUNEST_ARCH=$ARCH" > "${JUNEST_HOME}"/etc/junest/info
    assertCommandSuccess check_same_arch
}


source "$JUNEST_ROOT"/tests/utils/shunit2
