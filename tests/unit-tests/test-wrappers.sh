#!/bin/bash
# shellcheck disable=SC1091

source "$(dirname "$0")/../utils/utils.sh"

source "$(dirname "$0")/../../lib/core/wrappers.sh"

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
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers does not exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
}

function test_create_wrappers_not_executable_file(){
    touch "$JUNEST_HOME"/usr/bin/myfile
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should not exist" "[ ! -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
}

function test_create_wrappers_directory(){
    mkdir -p "$JUNEST_HOME"/usr/bin/mydir
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "mydir wrapper should not exist" "[ ! -e $JUNEST_HOME/usr/bin_wrappers/mydir ]"
}

function test_create_wrappers_broken_link(){
    ln -s /opt/myapp/bin/cmd "$JUNEST_HOME"/usr/bin/cmd
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "cmd wrapper should exist" "[ -x $JUNEST_HOME/usr/bin_wrappers/cmd ]"
}

function test_create_wrappers_executable_file(){
    touch "$JUNEST_HOME"/usr/bin/myfile
    chmod +x "$JUNEST_HOME"/usr/bin/myfile
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should exist" "[ -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
}

function test_create_wrappers_verify_content(){
    # Test for:
    # https://github.com/fsquillace/junest/issues/262
    # https://github.com/fsquillace/junest/issues/292
    touch "$JUNEST_HOME"/usr/bin/myfile
    chmod +x "$JUNEST_HOME"/usr/bin/myfile
    export JUNEST_ARGS="ns --fakeroot -b '--bind /run /run2'"
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat "$STDOUTF")"

    # Mock junest command to capture the actual output generated from myfile script
    # shellcheck disable=SC2317
    junest(){
        for arg in "$@"
        do
            echo "$arg"
        done
    }
    assertEquals "ns
--fakeroot
-b
--bind /run /run2
--
test-wrappers.sh
pacman
-Rsn
neovim
new package" "$(source "$JUNEST_HOME"/usr/bin_wrappers/myfile pacman -Rsn neovim 'new package')"
}

function test_create_wrappers_already_exist(){
    touch "$JUNEST_HOME"/usr/bin/myfile
    chmod +x "$JUNEST_HOME"/usr/bin/myfile
    mkdir -p "$JUNEST_HOME"/usr/bin_wrappers
    echo "original" > "$JUNEST_HOME"/usr/bin_wrappers/myfile
    chmod +x "$JUNEST_HOME"/usr/bin_wrappers/myfile
    assertCommandSuccess create_wrappers false
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should exist" "[ -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
    assertEquals "original" "$(cat "$JUNEST_HOME"/usr/bin_wrappers/myfile)"
}

function test_create_wrappers_forced_already_exist(){
    echo "new" > "$JUNEST_HOME"/usr/bin/myfile
    chmod +x "$JUNEST_HOME"/usr/bin/myfile
    mkdir -p "$JUNEST_HOME"/usr/bin_wrappers
    echo "original" > "$JUNEST_HOME"/usr/bin_wrappers/myfile
    chmod +x "$JUNEST_HOME"/usr/bin_wrappers/myfile
    assertCommandSuccess create_wrappers true
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should exist" "[ -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
    assertNotEquals "original" "$(cat "$JUNEST_HOME"/usr/bin_wrappers/myfile)"
}

function test_create_wrappers_executable_no_longer_exist(){
    mkdir -p "$JUNEST_HOME"/usr/bin_wrappers
    touch "$JUNEST_HOME"/usr/bin_wrappers/myfile
    chmod +x "$JUNEST_HOME"/usr/bin_wrappers/myfile
    assertCommandSuccess create_wrappers
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/bin_wrappers ]"
    assertTrue "myfile wrapper should not exist" "[ ! -x $JUNEST_HOME/usr/bin_wrappers/myfile ]"
}

function test_create_wrappers_custom_bin_path(){
    mkdir -p "$JUNEST_HOME"/usr/mybindir
    touch "$JUNEST_HOME"/usr/mybindir/myfile
    chmod +x "$JUNEST_HOME"/usr/mybindir/myfile
    assertCommandSuccess create_wrappers false /usr/mybindir/
    assertEquals "" "$(cat "$STDOUTF")"
    assertTrue "bin_wrappers should exist" "[ -e $JUNEST_HOME/usr/mybindir_wrappers ]"
    assertTrue "myfile wrapper should exist" "[ -x $JUNEST_HOME/usr/mybindir_wrappers/myfile ]"
}


source "$(dirname "$0")"/../utils/shunit2
