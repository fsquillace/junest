#!/bin/bash
source $(dirname $0)/../bin/juju -h &> /dev/null

# Disable the exiterr
set +e

## Mock functions ##
function usage(){
    echo "usage"
}
function version(){
    echo "version"
}
function build_image_juju(){
    echo "build_image_juju"
}
function delete_juju(){
    echo "delete_juju"
}
function is_juju_installed(){
    return 0
}
function setup_from_file_juju(){
    echo "setup_from_file_juju $@"
}
function setup_juju(){
    echo "setup_juju"
}
function run_juju_as_fakeroot(){
    local proot_args="$1"
    shift
    echo "run_juju_as_fakeroot($proot_args,$@)"
}
function run_juju_as_root(){
    echo "run_juju_as_root $@"
}
function run_juju_as_user(){
    local proot_args="$1"
    shift
    echo "run_juju_as_user($proot_args,$@)"
}

function wrap_juju(){
    parse_arguments "$@"
    check_cli
    execute_operation
}

function test_help(){
    local output=$(wrap_juju -h)
    assertEquals $output "usage"
    local output=$(wrap_juju --help)
    assertEquals $output "usage"
}
function test_version(){
    local output=$(wrap_juju -v)
    assertEquals $output "version"
    local output=$(wrap_juju --version)
    assertEquals $output "version"
}
function test_build_image_juju(){
    local output=$(wrap_juju -b)
    assertEquals $output "build_image_juju"
    local output=$(wrap_juju --build-image)
    assertEquals $output "build_image_juju"
}
function test_delete_juju(){
    local output=$(wrap_juju -d)
    assertEquals $output "delete_juju"
    local output=$(wrap_juju --delete)
    assertEquals $output "delete_juju"
}
function test_run_juju_as_fakeroot(){
    local output=$(wrap_juju -f)
    assertEquals $output "run_juju_as_fakeroot(,)"
    local output=$(wrap_juju --fakeroot)
    assertEquals $output "run_juju_as_fakeroot(,)"

    local output=$(wrap_juju -f -p "-b arg")
    assertEquals "${output[@]}" "run_juju_as_fakeroot(-b arg,)"
    local output=$(wrap_juju -f -p "-b arg" -- command -kv)
    assertEquals "${output[@]}" "run_juju_as_fakeroot(-b arg,command -kv)"
    local output=$(wrap_juju -f command --as)
    assertEquals "${output[@]}" "run_juju_as_fakeroot(,command --as)"
}
function test_run_juju_as_user(){
    local output=$(wrap_juju)
    assertEquals $output "run_juju_as_user(,)"

    local output=$(wrap_juju -p "-b arg")
    assertEquals "$output" "run_juju_as_user(-b arg,)"
    local output=$(wrap_juju -p "-b arg" -- command -ll)
    assertEquals "$output" "run_juju_as_user(-b arg,command -ll)"
    local output=$(wrap_juju command -ls)
    assertEquals "$output" "run_juju_as_user(,command -ls)"
}
function test_run_juju_as_root(){
    local output=$(wrap_juju -r)
    assertEquals $output "run_juju_as_root"

    local output=$(wrap_juju -r command)
    assertEquals "${output[@]}" "run_juju_as_root command"
}

function test_check_cli(){
    $(wrap_juju -b -h 2> /dev/null)
    assertEquals $? 1
    $(wrap_juju -n -v 2> /dev/null)
    assertEquals $? 1
    $(wrap_juju -d -r 2> /dev/null)
    assertEquals $? 1
    $(wrap_juju -h -f 2> /dev/null)
    assertEquals $? 1
    $(wrap_juju -v -i fsd 2> /dev/null)
    assertEquals $? 1
    $(wrap_juju -f -r 2> /dev/null)
    assertEquals $? 1
    $(wrap_juju -p args -v 2> /dev/null)
    assertEquals $? 1
    $(wrap_juju -d args 2> /dev/null)
    assertEquals $? 1
}

source $(dirname $0)/shunit2
