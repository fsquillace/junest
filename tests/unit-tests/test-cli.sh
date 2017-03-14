#!/bin/bash
source "$(dirname $0)/../utils/utils.sh"

source $(dirname $0)/../../bin/junest -h &> /dev/null

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
    assertCommandSuccess cli -h
    assertEquals "usage" "$(cat $STDOUTF)"
    assertCommandSuccess cli --help
    assertEquals "usage" "$(cat $STDOUTF)"
}
function test_version(){
    assertCommandSuccess cli -v
    assertEquals "version" "$(cat $STDOUTF)"
    assertCommandSuccess cli --version
    assertEquals "version" "$(cat $STDOUTF)"
}
function test_build_image_env(){
    assertCommandSuccess cli -b
    assertEquals "build_image_env(false,false)" "$(cat $STDOUTF)"
    assertCommandSuccess cli --build-image
    assertEquals "build_image_env(false,false)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -b -s
    assertEquals "build_image_env(false,true)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -b -n
    assertEquals "build_image_env(true,false)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -b -n -s
    assertEquals "build_image_env(true,true)" "$(cat $STDOUTF)"
    assertCommandSuccess cli --build-image --disable-validation --skip-root-tests
    assertEquals "build_image_env(true,true)" "$(cat $STDOUTF)"
}
function test_check_env(){
    assertCommandSuccess cli -c myscript
    assertEquals "check_env(${JUNEST_HOME},myscript,false)" "$(cat $STDOUTF)"
    assertCommandSuccess cli --check myscript
    assertEquals "check_env(${JUNEST_HOME},myscript,false)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -c myscript -s
    assertEquals "check_env(${JUNEST_HOME},myscript,true)" "$(cat $STDOUTF)"
    assertCommandSuccess cli --check myscript --skip-root-tests
    assertEquals "check_env(${JUNEST_HOME},myscript,true)" "$(cat $STDOUTF)"
}
function test_delete_env(){
    assertCommandSuccess cli -d
    assertEquals "delete_env" "$(cat $STDOUTF)"
    assertCommandSuccess cli --delete
    assertEquals "delete_env" "$(cat $STDOUTF)"
}
function test_setup_env_from_file(){
    is_env_installed(){
        return 1
    }
    assertCommandSuccess cli -i myimage
    assertEquals "$(echo -e "setup_env_from_file(myimage)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"
    assertCommandSuccess cli --setup-from-file myimage
    assertEquals "$(echo -e "setup_env_from_file(myimage)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"

    is_env_installed(){
        return 0
    }
    assertCommandFail cli -i myimage
}

function test_setup_env(){
    is_env_installed(){
        return 1
    }
    assertCommandSuccess cli -a arm
    assertEquals "$(echo -e "setup_env(arm)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"
    assertCommandSuccess cli --arch arm
    assertEquals "$(echo -e "setup_env(arm)\nrun_env_as_user(,)")" "$(cat $STDOUTF)"
    assertCommandSuccess cli
    assertEquals "$(echo -e "setup_env()\nrun_env_as_user(,)")" "$(cat $STDOUTF)"

    is_env_installed(){
        return 0
    }
    assertCommandFail cli -a arm
}
function test_run_env_as_fakeroot(){
    assertCommandSuccess cli -f
    assertEquals "run_env_as_fakeroot(,)" "$(cat $STDOUTF)"
    assertCommandSuccess cli --fakeroot
    assertEquals "run_env_as_fakeroot(,)" "$(cat $STDOUTF)"

    assertCommandSuccess cli -f -p "-b arg"
    assertEquals "run_env_as_fakeroot(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -f -p "-b arg" -- command -kv
    assertEquals "run_env_as_fakeroot(-b arg,command -kv)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -f command --as
    assertEquals "run_env_as_fakeroot(,command --as)" "$(cat $STDOUTF)"
    assertCommandFail cli -a "myarch" -f command --as
}
function test_run_env_as_user(){
    assertCommandSuccess cli
    assertEquals "run_env_as_user(,)" "$(cat $STDOUTF)"

    assertCommandSuccess cli -p "-b arg"
    assertEquals "run_env_as_user(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -p "-b arg" -- command -ll
    assertEquals "run_env_as_user(-b arg,command -ll)" "$(cat $STDOUTF)"
    assertCommandSuccess cli command -ls
    assertEquals "run_env_as_user(,command -ls)" "$(cat $STDOUTF)"

    assertCommandFail cli -a "myarch" -- command -ls
}
function test_run_env_as_root(){
    assertCommandSuccess cli -r
    assertEquals "run_env_as_root " "$(cat $STDOUTF)"
    assertCommandSuccess cli -r command
    assertEquals "run_env_as_root command" "$(cat $STDOUTF)"
}

function test_run_env_as_fakeroot_with_namespace(){
    assertCommandSuccess cli -u -f
    assertEquals "run_env_as_fakeroot_with_namespace(,)" "$(cat $STDOUTF)"
    assertCommandSuccess cli --user-namespace --fakeroot
    assertEquals "run_env_as_fakeroot_with_namespace(,)" "$(cat $STDOUTF)"

    assertCommandSuccess cli -u -f -p "-b arg"
    assertEquals "run_env_as_fakeroot_with_namespace(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -u -f -p "-b arg" -- command -kv
    assertEquals "run_env_as_fakeroot_with_namespace(-b arg,command -kv)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -u -f command --as
    assertEquals "run_env_as_fakeroot_with_namespace(,command --as)" "$(cat $STDOUTF)"
}
function test_run_env_as_user_with_namespace(){
    assertCommandSuccess cli -u
    assertEquals "run_env_as_user_with_namespace(,)" "$(cat $STDOUTF)"

    assertCommandSuccess cli -u -p "-b arg"
    assertEquals "run_env_as_user_with_namespace(-b arg,)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -u -p "-b arg" -- command -ll
    assertEquals "run_env_as_user_with_namespace(-b arg,command -ll)" "$(cat $STDOUTF)"
    assertCommandSuccess cli -u command -ls
    assertEquals "run_env_as_user_with_namespace(,command -ls)" "$(cat $STDOUTF)"
}

function test_check_cli(){
    assertCommandFail cli -b -h
    assertCommandFail cli -b -c
    assertCommandFail cli -d -s
    assertCommandFail cli -n -v
    assertCommandFail cli -d -r
    assertCommandFail cli -h -f
    assertCommandFail cli -v -i fsd
    assertCommandFail cli -f -r
    assertCommandFail cli -p args -v
    assertCommandFail cli -a arch -v
    assertCommandFail cli -d args
}

source $(dirname $0)/../utils/shunit2
