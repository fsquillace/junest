#!/bin/bash
source "$(dirname $0)/../utils/utils.sh"

JUNEST_BASE="$(dirname $0)/../.."
source $JUNEST_BASE/bin/junest -h &> /dev/null

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function setUp(){
    function is_env_installed(){
        return 0
    }
}

## Mock functions ##
function usage(){
    echo "usage"
}
function version(){
    echo "version"
}
function build_image_env(){
    local disable_check=$1
    echo "build_image_env($disable_check)"
}
function delete_env(){
    echo "delete_env"
}
function setup_env_from_file(){
    echo "setup_env_from_file($1)"
}
function setup_env(){
    echo "setup_env($1)"
}
function run_env_as_fakeroot(){
    local backend_args="$1"
    local no_copy_files="$2"
    shift 2
    echo "run_env_as_fakeroot($backend_args,$no_copy_files,$@)"
}
function run_env_as_groot(){
    local backend_args="$1"
    local no_copy_files="$2"
    shift 2
    echo "run_env_as_groot($backend_args,$no_copy_files,$@)"
}
function run_env_as_chroot(){
    local backend_args="$1"
    local no_copy_files="$2"
    shift 2
    echo "run_env_as_chroot($backend_args,$no_copy_files,$@)"
}
function run_env_as_user(){
    local backend_args="$1"
    local no_copy_files="$2"
    shift 2
    echo "run_env_as_user($backend_args,$no_copy_files,$@)"
}
function run_env_with_namespace(){
    local backend_args="$1"
    local no_copy_files="$2"
    shift 2
    echo "run_env_with_namespace($backend_args,$no_copy_files,$@)"
}

function test_help(){
    assertCommandSuccess main -h
    assertEquals "usage" "$(cat $STDOUTF)"
    assertCommandSuccess main --help
    assertEquals "usage" "$(cat $STDOUTF)"
}
function test_version(){
    assertCommandSuccess main -V
    assertEquals "version" "$(cat $STDOUTF)"
    assertCommandSuccess main --version
    assertEquals "version" "$(cat $STDOUTF)"
}
function test_build_image_env(){
    assertCommandSuccess main b
    assertEquals "build_image_env(false)" "$(cat $STDOUTF)"
    assertCommandSuccess main build
    assertEquals "build_image_env(false)" "$(cat $STDOUTF)"
    assertCommandSuccess main b -n
    assertEquals "build_image_env(true)" "$(cat $STDOUTF)"
    assertCommandSuccess main build --disable-check
    assertEquals "build_image_env(true)" "$(cat $STDOUTF)"
}

function test_delete_env(){
    assertCommandSuccess main s -d
    assertEquals "delete_env" "$(cat $STDOUTF)"
    assertCommandSuccess main setup --delete
    assertEquals "delete_env" "$(cat $STDOUTF)"
}
function test_setup_env_from_file(){
    is_env_installed(){
        return 1
    }
    assertCommandSuccess main s -i myimage
    assertEquals "setup_env_from_file(myimage)" "$(cat $STDOUTF)"
    assertCommandSuccess main setup --from-file myimage
    assertEquals "setup_env_from_file(myimage)" "$(cat $STDOUTF)"

    is_env_installed(){
        return 0
    }
    assertCommandFail main setup -i myimage
}

function test_setup_env(){
    is_env_installed(){
        return 1
    }
    assertCommandSuccess main s
    assertEquals "setup_env()" "$(cat $STDOUTF)"
    assertCommandSuccess main setup
    assertEquals "setup_env()" "$(cat $STDOUTF)"
    assertCommandSuccess main s -a arm
    assertEquals "setup_env(arm)" "$(cat $STDOUTF)"
    assertCommandSuccess main setup --arch arm
    assertEquals "setup_env(arm)" "$(cat $STDOUTF)"

    is_env_installed(){
        return 0
    }
    assertCommandFail main setup -a arm
}

function test_run_env_as_fakeroot(){
    assertCommandSuccess main p -f
    assertEquals "run_env_as_fakeroot(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main proot --fakeroot
    assertEquals "run_env_as_fakeroot(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main p -f -n
    assertEquals "run_env_as_fakeroot(,true,)" "$(cat $STDOUTF)"

    assertCommandSuccess main proot -f -b "-b arg"
    assertEquals "run_env_as_fakeroot(-b arg,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main proot -f -b "-b arg" -- command -kv
    assertEquals "run_env_as_fakeroot(-b arg,false,command -kv)" "$(cat $STDOUTF)"
    assertCommandSuccess main proot -f command --as
    assertEquals "run_env_as_fakeroot(,false,command --as)" "$(cat $STDOUTF)"
    assertCommandSuccess main proot -f  -- command --as
    assertEquals "run_env_as_fakeroot(,false,command --as)" "$(cat $STDOUTF)"

    is_env_installed(){
        return 1
    }
    assertCommandFail main proot -f
}

function test_run_env_as_user(){
    assertCommandSuccess main proot
    assertEquals "run_env_as_user(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main p -n
    assertEquals "run_env_as_user(,true,)" "$(cat $STDOUTF)"

    assertCommandSuccess main proot -b "-b arg"
    assertEquals "run_env_as_user(-b arg,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main proot -b "-b arg" -- command -ll
    assertEquals "run_env_as_user(-b arg,false,command -ll)" "$(cat $STDOUTF)"
    assertCommandSuccess main proot command -ls
    assertEquals "run_env_as_user(,false,command -ls)" "$(cat $STDOUTF)"
    assertCommandSuccess main proot -- command -ls
    assertEquals "run_env_as_user(,false,command -ls)" "$(cat $STDOUTF)"

    is_env_installed(){
        return 1
    }
    assertCommandFail main proot
}

function test_run_env_as_groot(){
    assertCommandSuccess main g
    assertEquals "run_env_as_groot(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main g -n
    assertEquals "run_env_as_groot(,true,)" "$(cat $STDOUTF)"
    assertCommandSuccess main g -b "-b arg"
    assertEquals "run_env_as_groot(-b arg,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main groot command
    assertEquals "run_env_as_groot(,false,command)" "$(cat $STDOUTF)"
    assertCommandSuccess main groot -- command
    assertEquals "run_env_as_groot(,false,command)" "$(cat $STDOUTF)"

    is_env_installed(){
        return 1
    }
    assertCommandFail main groot
}

function test_run_env_as_chroot(){
    assertCommandSuccess main r
    assertEquals "run_env_as_chroot(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main r -b "-b arg"
    assertEquals "run_env_as_chroot(-b arg,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main root command
    assertEquals "run_env_as_chroot(,false,command)" "$(cat $STDOUTF)"
    assertCommandSuccess main root -- command
    assertEquals "run_env_as_chroot(,false,command)" "$(cat $STDOUTF)"

    is_env_installed(){
        return 1
    }
    assertCommandFail main root -f
}

function test_run_env_with_namespace(){
    assertCommandSuccess main n
    assertEquals "run_env_with_namespace(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main ns
    assertEquals "run_env_with_namespace(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main ns -n
    assertEquals "run_env_with_namespace(,true,)" "$(cat $STDOUTF)"

    assertCommandSuccess main ns -b "-b arg"
    assertEquals "run_env_with_namespace(-b arg,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main ns -b "-b arg" -- command -kv
    assertEquals "run_env_with_namespace(-b arg,false,command -kv)" "$(cat $STDOUTF)"
    assertCommandSuccess main ns command --as
    assertEquals "run_env_with_namespace(,false,command --as)" "$(cat $STDOUTF)"
    assertCommandSuccess main ns -- command --as
    assertEquals "run_env_with_namespace(,false,command --as)" "$(cat $STDOUTF)"

    assertCommandSuccess main
    assertEquals "run_env_with_namespace(,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main
    assertEquals "run_env_with_namespace(,false,)" "$(cat $STDOUTF)"

    assertCommandSuccess main -b "-b arg"
    assertEquals "run_env_with_namespace(-b arg,false,)" "$(cat $STDOUTF)"
    assertCommandSuccess main -b "-b arg" -- command -kv
    assertEquals "run_env_with_namespace(-b arg,false,command -kv)" "$(cat $STDOUTF)"
    assertCommandSuccess main command --as
    assertEquals "run_env_with_namespace(,false,command --as)" "$(cat $STDOUTF)"
    assertCommandSuccess main -- command --as
    assertEquals "run_env_with_namespace(,false,command --as)" "$(cat $STDOUTF)"

    is_env_installed(){
        return 1
    }
    assertCommandFail main ns
}

function test_invalid_option(){
    assertCommandFail main --no-option
    assertCommandFail main n --no-option
    assertCommandFail main g --no-option
    assertCommandFail main r --no-option

    assertCommandFail main p --no-option

    assertCommandFail main b --no-option
    assertCommandFail main s --no-option
}

source $(dirname $0)/../utils/shunit2
