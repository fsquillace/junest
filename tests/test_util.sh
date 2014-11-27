#!/bin/bash
source "$(dirname $0)/utils.sh"
source "$(dirname $0)/../lib/util.sh"

function test_echoerr(){
    local actual=$(echoerr "Test" 2>&1)
    is_equal "$actual" "Test" || return 1
    return 0
}

function test_error(){
    local actual=$(error "Test" 2>&1)
    local expected=$(echo -e "\033[1;31mTest\033[0m")
    is_equal "$actual" "$expected" || return 1
    return 0
}

function test_warn(){
    local actual=$(warn "Test" 2>&1)
    local expected=$(echo -e "\033[1;33mTest\033[0m")
    is_equal "$actual" "$expected" || return 1
    return 0
}

function test_info(){
    local actual=$(info "Test")
    local expected=$(echo -e "\033[1;37mTest\033[0m")
    is_equal "$actual" "$expected" || return 1
    return 0
}

function test_die(){
    local actual=$(die "Test" 2>&1)
    local expected=$(echo -e "\033[1;31mTest\033[0m")
    is_equal "$actual" "$expected" || return 1
    export -f die
    bash -ic "die Dying" &> /dev/null
    is_equal $? 1 || return 1
    export -n die
    unset die
    return 0
}

function test_ask(){
    echo "Y" | ask "Test" &> /dev/null
    is_equal $? 0 || return 1
    echo "y" | ask "Test" &> /dev/null
    is_equal $? 0 || return 1
    echo "N" | ask "Test" &> /dev/null
    is_equal $? 1 || return 1
    echo "n" | ask "Test" &> /dev/null
    is_equal $? 1 || return 1
    echo -e "\n" | ask "Test" &> /dev/null
    is_equal $? 0 || return 1
    echo -e "\n" | ask "Test" "N" &> /dev/null
    is_equal $? 1 || return 1
    echo -e "asdf\n\n" | ask "Test" "N" &> /dev/null
    is_equal $? 1 || return 1
    return 0
}


for func in $(declare -F | grep test_ | awk '{print $3}' | xargs)
do
    $func && echo -e "${func}...\033[1;32mOK\033[0m" || echo -e "${func}...\033[1;31mFAIL\033[0m"
done
