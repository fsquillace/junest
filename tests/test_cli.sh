#!/bin/bash
source $(dirname $0)/../bin/junest -h &> /dev/null

# Disable the exiterr
set +e

## Mock functions ##
function usage(){
    echo "usage"
}
function version(){
    echo "version"
}
function build_image_env(){
    echo "build_image_env"
}
function delete_env(){
    echo "delete_env"
}
function is_env_installed(){
    return 0
}
function setup_env_from_file(){
    echo "setup_env_from_file $@"
}
function setup_env(){
    echo "setup_env"
}
function run_env_as_fakeroot(){
    local arch_arg="$1"
    local proot_args="$2"
    shift
    shift
    echo "run_env_as_fakeroot($arch_arg,$proot_args,$@)"
}
function run_env_as_root(){
    echo "run_env_as_root $@"
}
function run_env_as_user(){
    local arch_arg="$1"
    local proot_args="$2"
    shift
    shift
    echo "run_env_as_user($arch_arg,$proot_args,$@)"
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
    assertEquals $output "build_image_env"
    local output=$(wrap_env --build-image)
    assertEquals $output "build_image_env"
}
function test_delete_env(){
    local output=$(wrap_env -d)
    assertEquals $output "delete_env"
    local output=$(wrap_env --delete)
    assertEquals $output "delete_env"
}
function test_run_env_as_fakeroot(){
    local output=$(wrap_env -f)
    assertEquals $output "run_env_as_fakeroot(,,)"
    local output=$(wrap_env --fakeroot)
    assertEquals $output "run_env_as_fakeroot(,,)"

    local output=$(wrap_env -f -p "-b arg")
    assertEquals "${output[@]}" "run_env_as_fakeroot(,-b arg,)"
    local output=$(wrap_env -f -p "-b arg" -- command -kv)
    assertEquals "${output[@]}" "run_env_as_fakeroot(,-b arg,command -kv)"
    local output=$(wrap_env -f command --as)
    assertEquals "${output[@]}" "run_env_as_fakeroot(,,command --as)"
    local output=$(wrap_env -a "myarch" -f command --as)
    assertEquals "${output[@]}" "run_env_as_fakeroot(myarch,,command --as)"
}
function test_run_env_as_user(){
    local output=$(wrap_env)
    assertEquals $output "run_env_as_user(,,)"

    local output=$(wrap_env -p "-b arg")
    assertEquals "$output" "run_env_as_user(,-b arg,)"
    local output=$(wrap_env -p "-b arg" -- command -ll)
    assertEquals "$output" "run_env_as_user(,-b arg,command -ll)"
    local output=$(wrap_env command -ls)
    assertEquals "$output" "run_env_as_user(,,command -ls)"
    local output=$(wrap_env -a "myarch" -- command -ls)
    assertEquals "$output" "run_env_as_user(myarch,,command -ls)"
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
