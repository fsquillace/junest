#!/bin/bash
source "$(dirname $0)/../utils/utils.sh"

unset HOME
export HOME=$(TMPDIR=/tmp mktemp -d -t pearl-user-home.XXXXXXX)

source "$(dirname $0)/../../lib/utils/utils.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function test_check_not_null(){
    assertCommandFailOnStatus 11 check_not_null "" ""
    assertCommandSuccess check_not_null "bla" ""
}

function test_echoerr(){
    assertCommandSuccess echoerr "Test"
    assertEquals "Test" "$(cat $STDERRF)"
}

function test_error(){
    assertCommandSuccess error "Test"
    local expected=$(echo -e "\033[1;31mTest\033[0m")
    assertEquals "$expected" "$(cat $STDERRF)"
}

function test_warn(){
    assertCommandSuccess warn "Test"
    local expected=$(echo -e "\033[1;33mTest\033[0m")
    assertEquals "$expected" "$(cat $STDERRF)"
}

function test_info(){
    assertCommandSuccess info "Test"
    local expected=$(echo -e "\033[1;36mTest\033[0m")
    assertEquals "$expected" "$(cat $STDOUTF)"
}

function test_die(){
    assertCommandFail die "Test"
    local expected=$(echo -e "\033[1;31mTest\033[0m")
    assertEquals "$expected" "$(cat $STDERRF)"
}

function test_die_on_status(){
    assertCommandFailOnStatus 222 die_on_status 222 "Test"
    local expected=$(echo -e "\033[1;31mTest\033[0m")
    assertEquals "$expected" "$(cat $STDERRF)"
}

function test_ask_null_question(){
    assertCommandFailOnStatus 11 ask "" "Y"
}

function test_ask(){
    echo "Y" | ask "Test" &> /dev/null
    assertEquals 0 $?
    echo "y" | ask "Test" &> /dev/null
    assertEquals 0 $?
    echo "N" | ask "Test" &> /dev/null
    assertEquals 1 $?
    echo "n" | ask "Test" &> /dev/null
    assertEquals 1 $?
    echo -e "\n" | ask "Test" &> /dev/null
    assertEquals 0 $?
    echo -e "\n" | ask "Test" "N" &> /dev/null
    assertEquals 1 $?
    echo -e "asdf\n\n" | ask "Test" "N" &> /dev/null
    assertEquals 1 $?
}

function test_ask_wrong_default_answer() {
    echo "Y" | ask "Test" G &> /dev/null
    assertEquals 33 $?
}

function test_check_and_trap_fail() {
    trap echo EXIT
    trap ls QUIT
    assertCommandFailOnStatus 1 check_and_trap 'pwd' EXIT QUIT
}

function test_check_and_trap() {
    trap - EXIT QUIT
    assertCommandSuccess check_and_trap 'echo' EXIT QUIT
}

function test_check_and_force_trap_fail() {
    trap echo EXIT
    trap ls QUIT
    assertCommandSuccess check_and_force_trap 'echo' EXIT QUIT
}

function test_check_and_force_trap() {
    trap - EXIT QUIT
    assertCommandSuccess check_and_force_trap 'echo' EXIT QUIT
}

function test_insert_quotes_on_spaces(){
    assertCommandSuccess insert_quotes_on_spaces this is "a test"
    assertEquals "this is \"a test\"" "$(cat $STDOUTF)"

    assertCommandSuccess insert_quotes_on_spaces this is 'a test'
    assertEquals "this is \"a test\"" "$(cat $STDOUTF)"
}

function test_contains_element(){
    array=("something to search for" "a string" "test2000")
    assertCommandSuccess contains_element "a string" "${array[@]}"

    assertCommandFailOnStatus 1 contains_element "blabla" "${array[@]}"
}

source $(dirname $0)/../utils/shunit2
