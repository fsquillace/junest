#!/bin/bash
source "$(dirname $0)/../lib/util.sh"

# Disable the exiterr
set +e

function test_echoerr(){
    local actual=$(echoerr "Test" 2>&1)
    assertEquals "$actual" "Test"
}

function test_error(){
    local actual=$(error "Test" 2>&1)
    local expected=$(echo -e "\033[1;31mTest\033[0m")
    assertEquals "$actual" "$expected"
}

function test_warn(){
    local actual=$(warn "Test" 2>&1)
    local expected=$(echo -e "\033[1;33mTest\033[0m")
    assertEquals "$actual" "$expected"
}

function test_info(){
    local actual=$(info "Test")
    local expected=$(echo -e "\033[1;37mTest\033[0m")
    assertEquals "$actual" "$expected"
}

function test_die(){
    local actual=$(die "Test" 2>&1)
    local expected=$(echo -e "\033[1;31mTest\033[0m")
    assertEquals "$actual" "$expected"
    $(die Dying 2> /dev/null)
    assertEquals $? 1
}

function test_ask(){
    echo "Y" | ask "Test" &> /dev/null
    assertEquals $? 0
    echo "y" | ask "Test" &> /dev/null
    assertEquals $? 0
    echo "N" | ask "Test" &> /dev/null
    assertEquals $? 1
    echo "n" | ask "Test" &> /dev/null
    assertEquals $? 1
    echo -e "\n" | ask "Test" &> /dev/null
    assertEquals $? 0
    echo -e "\n" | ask "Test" "N" &> /dev/null
    assertEquals $? 1
    echo -e "asdf\n\n" | ask "Test" "N" &> /dev/null
    assertEquals $? 1
}

function test_insert_quotes_on_spaces(){
    local actual=$(insert_quotes_on_spaces this is "a test")
    assertEquals "this is \"a test\"" "$actual"

    local actual=$(insert_quotes_on_spaces this is 'a test')
    assertEquals "this is \"a test\"" "$actual"
}

function test_contains_element(){
    array=("something to search for" "a string" "test2000")
    contains_element "a string" "${array[@]}"
    assertEquals "$?" "0"

    contains_element "blabla" "${array[@]}"
    assertEquals "$?" "1"
}

source $(dirname $0)/shunit2
