#!/bin/bash
source "$(dirname $0)/utils.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    [ -z "$SKIP_ROOT_TESTS" ] && SKIP_ROOT_TESTS=0

    CURRPWD=$PWD
    ENV_MAIN_HOME=/tmp/junest-test-home
    [ -e $ENV_MAIN_HOME ] || JUNEST_HOME=$ENV_MAIN_HOME bash -ic "source $CURRPWD/$(dirname $0)/../lib/utils.sh; source $CURRPWD/$(dirname $0)/../lib/core.sh; setup_env"
    JUNEST_HOME=""
    setUpUnitTests
}

function install_mini_env(){
    cp -rfa $ENV_MAIN_HOME/* $JUNEST_HOME
}

function setUp(){
    cd $CURRPWD
    JUNEST_HOME=$(TMPDIR=/tmp mktemp -d -t envhome.XXXXXXXXXX)
    JUNEST_BASE="$CURRPWD/$(dirname $0)/.."
    source "${JUNEST_BASE}/lib/utils.sh"
    source "${JUNEST_BASE}/lib/core.sh"
    ORIGIN_WD=$(TMPDIR=/tmp mktemp -d -t envowd.XXXXXXXXXX)
    cd $ORIGIN_WD
    JUNEST_TEMPDIR=$(TMPDIR=/tmp mktemp -d -t envtemp.XXXXXXXXXX)

    set +e

    trap - QUIT EXIT ABRT KILL TERM INT
    trap "rm -rf ${JUNEST_HOME}; rm -rf ${ORIGIN_WD}; rm -rf ${JUNEST_TEMPDIR}" EXIT QUIT ABRT KILL TERM INT
}


function tearDown(){
    # the CA directories are read only and can be deleted only by changing the mod
    [ -d ${JUNEST_HOME}/etc/ca-certificates ] && chmod -R +w ${JUNEST_HOME}/etc/ca-certificates
    rm -rf $JUNEST_HOME
    rm -rf $ORIGIN_WD
    rm -rf $JUNEST_TEMPDIR
    trap - QUIT EXIT ABRT KILL TERM INT
}


function test_is_env_installed(){
    assertCommandFail is_env_installed
    touch $JUNEST_HOME/just_file
    assertCommandSuccess is_env_installed
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

function test_ln(){
    install_mini_env

    touch ln_file
    assertCommandSuccess ln_cmd -s ln_file new_file
    assertTrue "[ -e new_file ]"
    rm new_file

    touch ln_file
    OLDPATH="$PATH"
    PATH=""
    $(ln_cmd -s ln_file new_file 2> /dev/null)
    local ret=$?
    PATH="$OLDPATH"
    assertEquals $ret 0
    assertTrue "[ -e new_file ]"
}

function test_rm(){
    install_mini_env

    touch rm_file
    assertCommandSuccess rm_cmd rm_file
    assertTrue "[ ! -e rm_file ]"

    touch rm_file
    OLDPATH="$PATH"
    PATH=""
    rm_cmd rm_file 2> /dev/null
    local ret=$?
    PATH="$OLDPATH"
    assertEquals $ret 0
    assertTrue "[ ! -e rm_file ]"
}

function test_chown(){
    install_mini_env

    local id=$(id -u)

    touch chown_file
    assertCommandSuccess chown_cmd $id chown_file

    touch chown_file
    OLDPATH="$PATH"
    PATH=""
    chown_cmd $id chown_file 2> /dev/null
    local ret=$?
    PATH="$OLDPATH"
    assertEquals $ret 0
}

function test_mkdir(){
    install_mini_env

    assertCommandSuccess mkdir_cmd -p new_dir/new_dir
    assertTrue "[ -d new_dir/new_dir ]"
    rm -rf new_dir

    OLDPATH="$PATH"
    PATH=""
    mkdir_cmd -p new_dir/new_dir 2> /dev/null
    local ret=$?
    PATH="$OLDPATH"
    assertEquals $ret 0
    assertTrue "[ -d new_dir/new_dir ]"
}

function test_setup_env(){
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
    assertTrue "[ -e $JUNEST_HOME/run/lock ]"

    assertCommandFailOnStatus 102 setup_env "noarch"
}


function test_setup_env_from_file(){
    touch file
    tar -czvf ${CMD}-${ARCH}.tar.gz file 1> /dev/null
    setup_env_from_file ${CMD}-${ARCH}.tar.gz &> /dev/null
    assertTrue "[ -e $JUNEST_HOME/file ]"
    assertTrue "[ -e $JUNEST_HOME/run/lock ]"

    assertCommandFailOnStatus 103 setup_env_from_file noexist.tar.gz
}

function test_setup_env_from_file_with_absolute_path(){
    touch file
    tar -czvf ${CMD}-${ARCH}.tar.gz file 1> /dev/null
    setup_env_from_file ${ORIGIN_WD}/${CMD}-${ARCH}.tar.gz &> /dev/null
    assertTrue "[ -e $JUNEST_HOME/file ]"
    assertTrue "[ -e $JUNEST_HOME/run/lock ]"
}

function test_run_env_as_root(){
    [ $SKIP_ROOT_TESTS -eq 1 ] && return

    install_mini_env
    CHROOT="sudo $CHROOT"
    CLASSIC_CHROOT="sudo $CLASSIC_CHROOT"
    CHOWN="sudo $CHOWN"

    assertCommandSuccess run_env_as_root pwd
    assertEquals "/" "$(cat $STDOUTF)"
    assertCommandSuccess run_env_as_root [ -e /run/lock ]
    assertCommandSuccess run_env_as_root [ -e $HOME ]

    # test that normal user has ownership of the files created by root
    assertCommandSuccess run_env_as_root touch /a_root_file
    assertCommandSuccess run_env_as_root stat -c '%u' /a_root_file
    assertEquals "$UID" "$(cat $STDOUTF)"

    SH=("sh" "--login" "-c" "type -t type")
    assertCommandSuccess run_env_as_root
    assertEquals "builtin" "$(cat $STDOUTF)"
    SH=("sh" "--login" "-c" "[ -e /run/lock ]")
    assertCommandSuccess run_env_as_root
    SH=("sh" "--login" "-c" "[ -e $HOME ]")
    assertCommandSuccess run_env_as_root
}

function test_run_env_as_root_different_arch(){
    [ $SKIP_ROOT_TESTS -eq 1 ] && return

    install_mini_env
    echo "JUNEST_ARCH=XXX" > ${JUNEST_HOME}/etc/junest/info
    assertCommandFailOnStatus 104 run_env_as_root pwd
}

function test_run_env_as_classic_root(){
    [ $SKIP_ROOT_TESTS -eq 1 ] && return

    install_mini_env
    CHROOT="sudo unknowncommand"
    CLASSIC_CHROOT="sudo $CLASSIC_CHROOT"
    CHOWN="sudo $CHOWN"

    assertCommandSuccess run_env_as_root pwd
    assertEquals "/" "$(cat $STDOUTF)"
    assertCommandSuccess run_env_as_root [ -e /run/lock ]
}

function test_run_env_as_junest_root(){
    [ $SKIP_ROOT_TESTS -eq 1 ] && return

    install_mini_env
    CHROOT="sudo unknowncommand"
    CLASSIC_CHROOT="sudo unknowncommand"
    LD_EXEC="sudo $LD_EXEC"
    CHOWN="sudo $CHOWN"

    assertCommandSuccess run_env_as_root pwd
    assertEquals "/" "$(cat $STDOUTF)"
    assertCommandSuccess run_env_as_root [ -e /run/lock ]
    assertCommandFail run_env_as_root [ -e $HOME ]
}

function test_run_env_as_user(){
    install_mini_env
    assertCommandSuccess run_env_as_user "-k 3.10" "/usr/bin/mkdir" "-v" "/newdir2"
    assertEquals "/usr/bin/mkdir" "$(cat $STDOUTF| awk -F: '{print $1}')"
    assertTrue "[ -e $JUNEST_HOME/newdir2 ]"

    SH=("/usr/bin/echo")
    assertCommandSuccess run_env_as_user "-k 3.10"
    assertEquals "-c :" "$(cat $STDOUTF)"
}

function test_run_env_as_proot_mtab(){
    install_mini_env
    assertCommandSuccess run_env_as_fakeroot "-k 3.10" "echo"
    assertTrue "[ -e $JUNEST_HOME/etc/mtab ]"
    assertCommandSuccess run_env_as_user "-k 3.10" "echo"
    assertTrue "[ -e $JUNEST_HOME/etc/mtab ]"
}

function test_run_env_as_root_mtab(){
    [ $SKIP_ROOT_TESTS -eq 1 ] && return

    install_mini_env
    CHROOT="sudo $CHROOT"
    CLASSIC_CHROOT="sudo $CLASSIC_CHROOT"
    CHOWN="sudo $CHOWN"
    assertCommandSuccess run_env_as_root "echo"
    assertTrue "[ ! -e $JUNEST_HOME/etc/mtab ]"
}

function test_run_env_with_quotes(){
    install_mini_env
    assertCommandSuccess run_env_as_user "-k 3.10" "bash" "-c" "/usr/bin/mkdir -v /newdir2"
    assertEquals "/usr/bin/mkdir" "$(cat $STDOUTF| awk -F: '{print $1}')"
    assertTrue "[ -e $JUNEST_HOME/newdir2 ]"
}

function test_run_env_as_user_proot_args(){
    install_mini_env
    assertCommandSuccess run_env_as_user "--help" ""

    mkdir $JUNEST_TEMPDIR/newdir
    touch $JUNEST_TEMPDIR/newdir/newfile
    assertCommandSuccess run_env_as_user "-b $JUNEST_TEMPDIR/newdir:/newdir -k 3.10" "ls" "-l" "/newdir/newfile"

    assertCommandFail _run_env_with_proot --helps
}

function test_run_env_with_proot_compat(){
    PROOT="/bin/true"
    assertCommandSuccess _run_env_with_proot "" ""

    PROOT="/bin/false" assertCommandFail _run_env_with_proot --helps
}

function test_run_env_with_proot_as_root(){
    [ $SKIP_ROOT_TESTS -eq 1 ] && return

    install_mini_env

    assertCommandFail sudo run_env_as_user
    assertCommandFail sudo run_env_as_fakeroot
}

function test_run_proot_seccomp(){
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

function test_run_env_as_fakeroot(){
    install_mini_env
    assertCommandSuccess run_env_as_fakeroot "-k 3.10" "id"
    assertEquals "uid=0(root)" "$(cat $STDOUTF | awk '{print $1}')"
}

function test_delete_env(){
    install_mini_env
    echo "N" | delete_env 1> /dev/null
    assertCommandSuccess is_env_installed
    echo "Y" | delete_env 1> /dev/null
    assertCommandFail is_env_installed
}

function test_nested_env(){
    install_mini_env
    JUNEST_ENV=1 bash -ic "source $CURRPWD/$(dirname $0)/../lib/utils.sh; source $CURRPWD/$(dirname $0)/../lib/core.sh" &> /dev/null
    assertEquals 1 $?
}

source $(dirname $0)/shunit2
