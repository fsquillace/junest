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
    local disable_validation=$1
    local skip_root_tests=$2
    echo "build_image_env($disable_validation,$skip_root_tests)"
}
function check_env(){
    local env_home=$1
    local cmd_script=$2
    local skip_root_tests=$3
    echo "check_env($env_home,$cmd_script,$skip_root_tests)"
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
    shift
    echo "run_env_as_fakeroot($backend_args,$@)"
}
function run_env_as_root(){
    echo "run_env_as_root $@"
}
function run_env_as_user(){
    local backend_args="$1"
    shift
    echo "run_env_as_user($backend_args,$@)"
}
function run_env_as_fakeroot_with_namespace(){
    local backend_args="$1"
    shift
    echo "run_env_as_fakeroot_with_namespace($backend_args,$@)"
}
function run_env_as_user_with_namespace(){
    local backend_args="$1"
    shift
    echo "run_env_as_user_with_namespace($backend_args,$@)"
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
    assertCommandSuccess main -b
    assertEquals "build_image_env(false,false)" "$(cat $STDOUTF)"
    assertCommandSuccess main --build-image
    assertEquals "build_image_env(false,false)" "$(cat $STDOUTF)"
    assertCommandSuccess main -b -s
    assertEquals "build_image_env(false,true)" "$(cat $STDOUTF)"
    assertCommandSuccess main -b -n
    assertEquals "build_image_env(true,false)" "$(cat $STDOUTF)"
    assertCommandSuccess main -b -n -s
    assertEquals "build_image_env(true,true)" "$(cat $STDOUTF)"
    assertCommandSuccess main --build-image --disable-validation --skip-root-tests
    assertEquals "build_image_env(true,true)" "$(cat $STDOUTF)"
}
function test_check_env(){
    assertCommandSuccess main -c myscript
    assertEquals "check_env(${JUNEST_HOME},myscript,false)" "$(cat $STDOUTF)"
    assertCommandSuccess main --check myscript
    assertEquals "check_env(${JUNEST_HOME},myscript,false)" "$(cat $STDOUTF)"
    assertCommandSuccess main -c myscript -s
    assertEquals "check_env(${JUNEST_HOME},myscript,true)" "$(cat $STDOUTF)"
    assertCommandSuccess main --check myscript --skip-root-tests
    assertEquals "check_env(${JUNEST_HOME},myscript,true)" "$(cat $STDOUTF)"
}
function test_delete_env(){
    assertCommandSuccess main -d
    assertEquals "delete_env" "$(cat $STDOUTF)"
    assertCommandSuccess main --delete
    assertEquals "delete_env" "$(cat $STDOUTF)"
}
function test_setup_env_from_file(){
    is_env_installed(){
        return 1
    }
    assertCommandSuccess main -i myimage
    assertEquals "$(echo -e "setup_env_from_file(myimage)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"
    assertCommandSuccess main --setup-from-file myimage
    assertEquals "$(echo -e "setup_env_from_file(myimage)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"

    is_env_installed(){
        return 0
    }
    assertCommandFail main -i myimage
}

function test_setup_env(){
    is_env_installed(){
        return 1
    }
    assertCommandSuccess main -a arm
    assertEquals "$(echo -e "setup_env(arm)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"
    assertCommandSuccess main --arch arm
    assertEquals "$(echo -e "setup_env(arm)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"
    assertCommandSuccess main
    assertEquals "$(echo -e "setup_env()\nrun_env_as_user(,)")" "$(cat $STDOUTF)"

    is_env_installed(){
        return 0
    }
    assertCommandFail main -a arm
}
function test_run_env_as_fakeroot(){
    assertCommandSuccess main -f
    assertEquals "run_env_as_fakeroot(,)" "$(cat $STDOUTF)"
    assertCommandSuccess main --fakeroot
    assertEquals "run_env_as_fakeroot(,)" "$(cat $STDOUTF)"

    assertCommandSuccess main -f -p "-b arg"
    assertEquals "run_env_as_fakeroot(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess main -f -p "-b arg" -- command -kv
    assertEquals "run_env_as_fakeroot(-b arg,command -kv)" "$(cat $STDOUTF)"
    assertCommandSuccess main -f command --as
    assertEquals "run_env_as_fakeroot(,command --as)" "$(cat $STDOUTF)"
    assertCommandFail main -a "myarch" -f command --as
}
function test_run_env_as_user(){
    assertCommandSuccess main
    assertEquals "run_env_as_user(,)" "$(cat $STDOUTF)"

    assertCommandSuccess main -p "-b arg"
    assertEquals "run_env_as_user(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess main -p "-b arg" -- command -ll
    assertEquals "run_env_as_user(-b arg,command -ll)" "$(cat $STDOUTF)"
    assertCommandSuccess main command -ls
    assertEquals "run_env_as_user(,command -ls)" "$(cat $STDOUTF)"

    assertCommandFail main -a "myarch" -- command -ls
}
function test_run_env_as_root(){
    assertCommandSuccess main -r
    assertEquals "run_env_as_root " "$(cat $STDOUTF)"
    assertCommandSuccess main -r command
    assertEquals "run_env_as_root command" "$(cat $STDOUTF)"
}

function test_run_env_as_fakeroot_with_namespace(){
    assertCommandSuccess main -u -f
    assertEquals "run_env_as_fakeroot_with_namespace(,)" "$(cat $STDOUTF)"
    assertCommandSuccess main --user-namespace --fakeroot
    assertEquals "run_env_as_fakeroot_with_namespace(,)" "$(cat $STDOUTF)"

    assertCommandSuccess main -u -f -p "-b arg"
    assertEquals "run_env_as_fakeroot_with_namespace(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess main -u -f -p "-b arg" -- command -kv
    assertEquals "run_env_as_fakeroot_with_namespace(-b arg,command -kv)" "$(cat $STDOUTF)"
    assertCommandSuccess main -u -f command --as
    assertEquals "run_env_as_fakeroot_with_namespace(,command --as)" "$(cat $STDOUTF)"
}
function test_run_env_as_user_with_namespace(){
    assertCommandSuccess main -u
    assertEquals "run_env_as_user_with_namespace(,)" "$(cat $STDOUTF)"

    assertCommandSuccess main -u -p "-b arg"
    assertEquals "run_env_as_user_with_namespace(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess main -u -p "-b arg" -- command -ll
    assertEquals "run_env_as_user_with_namespace(-b arg,command -ll)" "$(cat $STDOUTF)"
    assertCommandSuccess main -u command -ls
    assertEquals "run_env_as_user_with_namespace(,command -ls)" "$(cat $STDOUTF)"
}

function test_check_cli(){
    assertCommandFail main -b -h
    assertCommandFail main -b -c
    assertCommandFail main -d -s
    assertCommandFail main -n -v
    assertCommandFail main -d -r
    assertCommandFail main -h -f
    assertCommandFail main -v -i fsd
    assertCommandFail main -f -r
    assertCommandFail main -p args -v
    assertCommandFail main -a arch -v
    assertCommandFail main -d args
}

source $(dirname $0)/../utils/shunit2
