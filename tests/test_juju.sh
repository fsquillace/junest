#!/bin/bash
source "$(dirname $0)/utils.sh"
source $(dirname $0)/../bin/juju -h &> /dev/null
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


function set_up(){
    echo > /dev/null
}

function tear_down(){
    echo > /dev/null
}


function test_help(){
    local output=$(wrap_juju -h)
    is_equal $output "usage" || return 1
    local output=$(wrap_juju --help)
    is_equal $output "usage" || return 1
}
function test_version(){
    local output=$(wrap_juju -v)
    is_equal $output "version" || return 1
    local output=$(wrap_juju --version)
    is_equal $output "version" || return 1
}
function test_build_image_juju(){
    local output=$(wrap_juju -b)
    is_equal $output "build_image_juju" || return 1
    local output=$(wrap_juju --build-image)
    is_equal $output "build_image_juju" || return 1
}
function test_delete_juju(){
    local output=$(wrap_juju -d)
    is_equal $output "delete_juju" || return 1
    local output=$(wrap_juju --delete)
    is_equal $output "delete_juju" || return 1
}
function test_run_juju_as_fakeroot(){
    local output=$(wrap_juju -f)
    is_equal $output "run_juju_as_fakeroot(,)" || return 1
    local output=$(wrap_juju --fakeroot)
    is_equal $output "run_juju_as_fakeroot(,)" || return 1

    local output=$(wrap_juju -f -p "-b arg")
    is_equal "${output[@]}" "run_juju_as_fakeroot(-b arg,)" || return 1
    local output=$(wrap_juju -f -p "-b arg" -- command -kv)
    is_equal "${output[@]}" "run_juju_as_fakeroot(-b arg,command -kv)" || return 1
    local output=$(wrap_juju -f command --as)
    is_equal "${output[@]}" "run_juju_as_fakeroot(,command --as)" || return 1
}
function test_run_juju_as_user(){
    local output=$(wrap_juju)
    is_equal $output "run_juju_as_user(,)" || return 1

    local output=$(wrap_juju -p "-b arg")
    is_equal "${output[@]}" "run_juju_as_user(-b arg,)" || return 1
    local output=$(wrap_juju -p "-b arg" -- command -ll)
    is_equal "${output[@]}" "run_juju_as_user(-b arg,command -ll)" || return 1
    local output=$(wrap_juju command -ls)
    is_equal "${output[@]}" "run_juju_as_user(,command -ls)" || return 1
}
function test_run_juju_as_root(){
    local output=$(wrap_juju -r)
    is_equal $output "run_juju_as_root" || return 1

    local output=$(wrap_juju -r command)
    is_equal "${output[@]}" "run_juju_as_root command" || return 1
}

function test_check_cli(){
    export -f check_cli
    export -f parse_arguments
    export -f execute_operation
    export -f wrap_juju
    export -f die
    bash -ic "wrap_juju -b -h" &> /dev/null
    is_equal $? 1 || return 1
    bash -ic "wrap_juju -d -r" &> /dev/null
    is_equal $? 1 || return 1
    bash -ic "wrap_juju -h -f" &> /dev/null
    is_equal $? 1 || return 1
    bash -ic "wrap_juju -v -i fsd" &> /dev/null
    is_equal $? 1 || return 1
    bash -ic "wrap_juju -f -r" &> /dev/null
    is_equal $? 1 || return 1
    bash -ic "wrap_juju -p args -v" &> /dev/null
    is_equal $? 1 || return 1
    bash -ic "wrap_juju -d args" &> /dev/null
    is_equal $? 1 || return 1
    export -n check_cli
    export -n parse_arguments
    export -n execute_operation
    export -n wrap_juju
    export -n die
    unset die
}

for func in $(declare -F | grep test_ | awk '{print $3}' | xargs)
do
    set_up
    $func && echo -e "${func}...\033[1;32mOK\033[0m" || echo -e "${func}...\033[1;31mFAIL\033[0m"
    tear_down
done
