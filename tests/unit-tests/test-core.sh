#!/bin/bash

JUNEST_ROOT=$(readlink -f $(dirname $0)/../..)

source "$JUNEST_ROOT/tests/unit-tests/utils.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    SKIP_ROOT_TESTS=${SKIP_ROOT_TESTS:-0}
    setUpUnitTests
}

function setUp(){
    ORIGIN_CWD=$(TMPDIR=/tmp mktemp -d -t junest-cwd.XXXXXXXXXX)
    cd $ORIGIN_CWD
    JUNEST_HOME=$(TMPDIR=/tmp mktemp -d -t junest-home.XXXXXXXXXX)
    mkdir -p ${JUNEST_HOME}/etc/junest
    echo "JUNEST_ARCH=x86_64" > ${JUNEST_HOME}/etc/junest/info
    mkdir -p ${JUNEST_HOME}/etc/ca-certificates
    JUNEST_TEMPDIR=$(TMPDIR=/tmp mktemp -d -t junest-temp.XXXXXXXXXX)
    source "$JUNEST_ROOT/lib/utils.sh"
    source "$JUNEST_ROOT/lib/core.sh"

    set +e

    trap - QUIT EXIT ABRT KILL TERM INT
    trap "rm -rf ${JUNEST_HOME}; rm -rf ${JUNEST_TEMPDIR}" EXIT QUIT ABRT KILL TERM INT

    ld_exec() {
        echo "ld_exec $@"
    }
    LD_EXEC=ld_exec
}


function tearDown(){
    # the CA directories are read only and can be deleted only by changing the mod
    [ -d ${JUNEST_HOME}/etc/ca-certificates ] && chmod -R +w ${JUNEST_HOME}/etc/ca-certificates
    rm -rf $JUNEST_HOME
    rm -rf $JUNEST_TEMPDIR
    rm -rf $ORIGIN_CWD
    trap - QUIT EXIT ABRT KILL TERM INT
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

function test_chroot(){
    CHROOT=echo assertCommandSuccess chroot_cmd root
    assertEquals "root" "$(cat $STDOUTF)"

    CHROOT=false CLASSIC_CHROOT=echo assertCommandSuccess chroot_cmd root
    assertEquals "root" "$(cat $STDOUTF)"

    CHROOT=false CLASSIC_CHROOT=false assertCommandSuccess chroot_cmd root
    assertEquals "ld_exec $JUNEST_HOME/usr/bin/chroot root" "$(cat $STDOUTF)"

    CHROOT=false CLASSIC_CHROOT=false LD_EXEC=false assertCommandFail chroot_cmd root
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

function test_is_env_installed(){
    rm -rf $JUNEST_HOME/*
    assertCommandFail is_env_installed
    touch $JUNEST_HOME/just_file
    assertCommandSuccess is_env_installed
}

function test_setup_env(){
    rm -rf $JUNEST_HOME/*
    wget_mock(){
        # Proof that the setup is happening
        # inside $JUNEST_TEMPDIR
        local cwd=${PWD#${JUNEST_TEMPDIR}}
        local parent_dir=${PWD%${cwd}}
        assertEquals "$JUNEST_TEMPDIR" "${parent_dir}"
        touch file
        tar -czvf ${CMD}-${ARCH}.tar.gz file
    }
    WGET=wget_mock
    setup_env 1> /dev/null
    assertTrue "[ -e $JUNEST_HOME/file ]"

    assertCommandFailOnStatus 102 setup_env "noarch"
}


function test_setup_env_from_file(){
    rm -rf $JUNEST_HOME/*
    touch file
    tar -czvf ${CMD}-${ARCH}.tar.gz file 1> /dev/null
    assertCommandSuccess setup_env_from_file ${CMD}-${ARCH}.tar.gz
    assertTrue "[ -e $JUNEST_HOME/file ]"
}

function test_setup_env_from_file_not_existing_file(){
    assertCommandFailOnStatus 103 setup_env_from_file noexist.tar.gz
}

function test_setup_env_from_file_with_absolute_path(){
    rm -rf $JUNEST_HOME/*
    touch file
    tar -czvf ${CMD}-${ARCH}.tar.gz file 1> /dev/null
    assertCommandSuccess setup_env_from_file ${ORIGIN_WD}/${CMD}-${ARCH}.tar.gz
    assertTrue "[ -e $JUNEST_HOME/file ]"
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

function test_run_env_as_user(){
    _run_env_with_qemu() {
        echo $@
    }
    assertCommandSuccess run_env_as_user "-k 3.10" "/usr/bin/mkdir" "-v" "/newdir2"
    _provide_bindings_as_user
    assertEquals "${RESULT}-r ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat $STDOUTF)"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_user "-k 3.10"
    _provide_bindings_as_user
    assertEquals "${RESULT}-r ${JUNEST_HOME} -k 3.10" "$(cat $STDOUTF)"
}

function test_provide_bindings_as_user_no_junest_home(){
    _provide_bindings_as_user
    echo "$RESULT" | grep -q "$JUNEST_HOME/etc/junest/passwd"
    assertEquals 1 $?
    echo "$RESULT" | grep -q "$JUNEST_HOME/etc/junest/group"
    assertEquals 1 $?
}

function test_provide_bindings_as_user(){
    touch $JUNEST_HOME/etc/junest/passwd
    touch $JUNEST_HOME/etc/junest/group
    _provide_bindings_as_user
    echo "$RESULT" | grep -q "$JUNEST_HOME/etc/junest/passwd"
    assertEquals 0 $?
    echo "$RESULT" | grep -q "$JUNEST_HOME/etc/junest/group"
    assertEquals 0 $?
}

function test_build_passwd_and_group(){
    getent_cmd_mock() {
        echo $@
    }
    GETENT=getent_cmd_mock assertCommandSuccess _build_passwd_and_group
    assertEquals "passwd" "$(cat $JUNEST_HOME/etc/junest/passwd)"
    assertEquals "group" "$(cat $JUNEST_HOME/etc/junest/group)"
}

function test_build_passwd_and_group_fallback(){
    cp_cmd_mock() {
        echo $@
    }
    CP=cp_cmd_mock GETENT=false LD_EXEC=false assertCommandSuccess _build_passwd_and_group
    assertEquals "$(echo -e "/etc/passwd $JUNEST_HOME/etc/junest/passwd\n/etc/group $JUNEST_HOME/etc/junest/group")" "$(cat $STDOUTF)"
}

function test_build_passwd_and_group_failure(){
    CP=false GETENT=false LD_EXEC=false assertCommandFailOnStatus 1 _build_passwd_and_group
}

function test_run_env_as_fakeroot(){
    _run_env_with_qemu() {
        echo $@
    }
    assertCommandSuccess run_env_as_fakeroot "-k 3.10" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "-S ${JUNEST_HOME} -k 3.10 /usr/bin/mkdir -v /newdir2" "$(cat $STDOUTF)"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_fakeroot "-k 3.10"
    assertEquals "-S ${JUNEST_HOME} -k 3.10" "$(cat $STDOUTF)"
}

function test_run_env_with_quotes(){
    _run_env_with_qemu() {
        echo $@
    }
    assertCommandSuccess run_env_as_user "-k 3.10" "bash" "-c" "/usr/bin/mkdir -v /newdir2"
    _provide_bindings_as_user
    assertEquals "${RESULT}-r ${JUNEST_HOME} -k 3.10 bash -c /usr/bin/mkdir -v /newdir2" "$(cat $STDOUTF)"
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

function test_delete_env(){
    echo "N" | delete_env 1> /dev/null
    assertCommandSuccess is_env_installed
    echo "Y" | delete_env 1> /dev/null
    assertCommandFail is_env_installed
}

function test_nested_env(){
    JUNEST_ENV=1 assertCommandFailOnStatus 106 bash -ic "source $JUNEST_ROOT/lib/utils.sh; source $JUNEST_ROOT/lib/core.sh"
}

function test_nested_env_not_set_variable(){
    JUNEST_ENV=aaa assertCommandFailOnStatus 107 bash -ic "source $JUNEST_ROOT/lib/utils.sh; source $JUNEST_ROOT/lib/core.sh"
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

source $JUNEST_ROOT/tests/unit-tests/shunit2
