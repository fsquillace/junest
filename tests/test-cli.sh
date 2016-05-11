#!/bin/bash
source $(dirname $0)/../bin/junest -h &> /dev/null

# Disable the exiterr
set +e

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
    local proot_args="$1"
    shift
    echo "run_env_as_fakeroot($proot_args,$@)"
}
function run_env_as_root(){
    echo "run_env_as_root $@"
}
function run_env_as_user(){
    local proot_args="$1"
    shift
    echo "run_env_as_user($proot_args,$@)"
}

function wrap_env(){
    parse_arguments "$@"
    check_cli
    execute_operation
}

function test_help(){
    local output=$(wrap_env -h)
    assertEquals $output "usage"
    local output=$(wrap_env --help)
    assertEquals $output "usage"
}
function test_version(){
    local output=$(wrap_env -v)
    assertEquals $output "version"
    local output=$(wrap_env --version)
    assertEquals $output "version"
}
function test_build_image_env(){
    local output=$(wrap_env -b)
    assertEquals $output "build_image_env(false,false)"
    local output=$(wrap_env --build-image)
    assertEquals $output "build_image_env(false,false)"
    local output=$(wrap_env -b -s)
    assertEquals $output "build_image_env(false,true)"
    local output=$(wrap_env -b -n)
    assertEquals $output "build_image_env(true,false)"
    local output=$(wrap_env -b -n -s)
    assertEquals $output "build_image_env(true,true)"
    local output=$(wrap_env --build-image --disable-validation --skip-root-tests)
    assertEquals $output "build_image_env(true,true)"
}
function test_check_env(){
    local output=$(wrap_env -c myscript)
    assertEquals $output "check_env(${JUNEST_HOME},myscript,false)"
    local output=$(wrap_env --check myscript)
    assertEquals $output "check_env(${JUNEST_HOME},myscript,false)"
    local output=$(wrap_env -c myscript -s)
    assertEquals $output "check_env(${JUNEST_HOME},myscript,true)"
    local output=$(wrap_env --check myscript --skip-root-tests)
    assertEquals $output "check_env(${JUNEST_HOME},myscript,true)"
}
function test_delete_env(){
    local output=$(wrap_env -d)
    assertEquals $output "delete_env"
    local output=$(wrap_env --delete)
    assertEquals $output "delete_env"
}
#function test_setup_env_from_file(){
    #local output=$(wrap_env -i myimage)
    #assertEquals $output "setup_env_from_file(myimage)"
    #local output=$(wrap_env --setup-from-file myimage)
    #assertEquals $output "setup_env_from_file(myimage)"
#}
function test_setup_env_from_file(){
    is_env_installed(){
        return 1
    }
    local output=$(wrap_env -i myimage)
    assertEquals "$output" "$(echo -e "setup_env_from_file(myimage)\nrun_env_as_user(,)")"
    local output=$(wrap_env --setup-from-file myimage)
    assertEquals "$output" "$(echo -e "setup_env_from_file(myimage)\nrun_env_as_user(,)")"

    is_env_installed(){
        return 0
    }
    $(wrap_env -i myimage 2> /dev/null)
    assertEquals 1 $?
}

function test_setup_env(){
    is_env_installed(){
        return 1
    }
    local output=$(wrap_env -a arm)
    assertEquals "$output" "$(echo -e "setup_env(arm)\nrun_env_as_user(,)")"
    local output=$(wrap_env --arch arm)
    assertEquals "$output" "$(echo -e "setup_env(arm)\nrun_env_as_user(,)")"
    local output=$(wrap_env)
    assertEquals "$output" "$(echo -e "setup_env()\nrun_env_as_user(,)")"

    is_env_installed(){
        return 0
    }
    $(wrap_env -a arm 2> /dev/null)
    assertEquals 1 $?
}
function test_run_env_as_fakeroot(){
    local output=$(wrap_env -f)
    assertEquals $output "run_env_as_fakeroot(,)"
    local output=$(wrap_env --fakeroot)
    assertEquals $output "run_env_as_fakeroot(,)"

    local output=$(wrap_env -f -p "-b arg")
    assertEquals "${output[@]}" "run_env_as_fakeroot(-b arg,)"
    local output=$(wrap_env -f -p "-b arg" -- command -kv)
    assertEquals "${output[@]}" "run_env_as_fakeroot(-b arg,command -kv)"
    local output=$(wrap_env -f command --as)
    assertEquals "${output[@]}" "run_env_as_fakeroot(,command --as)"
    $(wrap_env -a "myarch" -f command --as 2> /dev/null)
    assertEquals 1 $?
}
function test_run_env_as_user(){
    local output=$(wrap_env)
    assertEquals $output "run_env_as_user(,)"

    local output=$(wrap_env -p "-b arg")
    assertEquals "$output" "run_env_as_user(-b arg,)"
    local output=$(wrap_env -p "-b arg" -- command -ll)
    assertEquals "$output" "run_env_as_user(-b arg,command -ll)"
    local output=$(wrap_env command -ls)
    assertEquals "$output" "run_env_as_user(,command -ls)"
    $(wrap_env -a "myarch" -- command -ls 2> /dev/null)
    assertEquals 1 $?
}
function test_run_env_as_root(){
    local output=$(wrap_env -r)
    assertEquals $output "run_env_as_root"

    local output=$(wrap_env -r command)
    assertEquals "${output[@]}" "run_env_as_root command"
}

function test_check_cli(){
    $(wrap_env -b -h 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -b -c 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -d -s 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -n -v 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -d -r 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -h -f 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -v -i fsd 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -f -r 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -p args -v 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -a arch -v 2> /dev/null)
    assertEquals $? 1
    $(wrap_env -d args 2> /dev/null)
    assertEquals $? 1
}

source $(dirname $0)/shunit2
