#!/usr/bin/env bash

source "$(dirname $0)/../utils/utils.sh"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function test_check_no_tabs(){
    assertCommandFailOnStatus 1 grep -R "$(printf '\t')" $(dirname $0)/../../bin/*
    assertEquals "" "$(cat $STDOUTF)"
    assertEquals "" "$(cat $STDERRF)"
    assertCommandFailOnStatus 1 grep -R "$(printf '\t')" $(dirname $0)/../../lib/*
    assertEquals "" "$(cat $STDOUTF)"
    assertEquals "" "$(cat $STDERRF)"
}

source $(dirname $0)/../utils/shunit2
