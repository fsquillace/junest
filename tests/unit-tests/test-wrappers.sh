#!/bin/bash
source "$(dirname $0)/../utils/utils.sh"

source "$(dirname $0)/../../lib/core/wrappers.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function setUp(){
    junestSetUp
}

function tearDown(){
    junestTearDown
}

function test_create_wrappers_empty_bin(){
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat $STDOUTF)"
    assertTrue "bin_wrappers does not exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
}

function test_create_wrappers_not_executable_file(){
    touch $JUNEST_HOME/usr/bin/myfile
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat $STDOUTF)"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should not exist" "[ ! -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
}

function test_create_wrappers_executable_file(){
    touch $JUNEST_HOME/usr/bin/myfile
    chmod +x $JUNEST_HOME/usr/bin/myfile
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat $STDOUTF)"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should exist" "[ -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
}

function test_create_wrappers_already_exist(){
    touch $JUNEST_HOME/usr/bin/myfile
    chmod +x $JUNEST_HOME/usr/bin/myfile
    mkdir -p $JUNEST_HOME/usr/bin_wrappers
    touch $JUNEST_HOME/usr/bin_wrappers/myfile
    chmod +x $JUNEST_HOME/usr/bin_wrappers/myfile
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat $STDOUTF)"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should exist" "[ -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
    assertEquals "" "$(touch $JUNEST_HOME/usr/bin_wrappers/myfile)"
}

function test_create_wrappers_executable_no_longer_exist(){
    mkdir -p $JUNEST_HOME/usr/bin_wrappers
    touch $JUNEST_HOME/usr/bin_wrappers/myfile
    chmod +x $JUNEST_HOME/usr/bin_wrappers/myfile
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat $STDOUTF)"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should not exist" "[ ! -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
}

source $(dirname $0)/../utils/shunit2
