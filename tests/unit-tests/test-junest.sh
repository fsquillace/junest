#!/bin/bash
# shellcheck disable=SC1091

source "$(dirname "$0")/../utils/utils.sh"

JUNEST_BASE="$(dirname "$0")/../.."
source "$JUNEST_BASE"/bin/junest -h &> /dev/null

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function setUp(){
    ## Mock functions ##
    # shellcheck disable=SC2317
    function usage(){
        echo "usage"
    }
    # shellcheck disable=SC2317
    function version(){
        echo "version"
    }
    # shellcheck disable=SC2317
    function build_image_env(){
        local disable_check=$1
        echo "build_image_env($disable_check)"
    }
    # shellcheck disable=SC2317
    function delete_env(){
        echo "delete_env"
    }
    # shellcheck disable=SC2317
    function setup_env_from_file(){
        echo "setup_env_from_file($1)"
    }
    # shellcheck disable=SC2317
    function setup_env(){
        echo "setup_env($1)"
    }
    # shellcheck disable=SC2317
    function run_env_as_proot_fakeroot(){
        local backend_command="$1"
        local backend_args="$2"
        local no_copy_files="$3"
        shift 3
        echo "run_env_as_proot_fakeroot($backend_command,$backend_args,$no_copy_files,$*)"
    }
    # shellcheck disable=SC2317
    function run_env_as_groot(){
        local backend_command="$1"
        local backend_args="$2"
        local no_copy_files="$3"
        shift 3
        echo "run_env_as_groot($backend_command,$backend_args,$no_copy_files,$*)"
    }
    # shellcheck disable=SC2317
    function run_env_as_chroot(){
        local backend_command="$1"
        local backend_args="$2"
        local no_copy_files="$3"
        shift 3
        echo "run_env_as_chroot($backend_command,$backend_args,$no_copy_files,$*)"
    }
    # shellcheck disable=SC2317
    function run_env_as_proot_user(){
        local backend_command="$1"
        local backend_args="$2"
        local no_copy_files="$3"
        shift 3
        echo "run_env_as_proot_user($backend_command,$backend_args,$no_copy_files,$*)"
    }
    # shellcheck disable=SC2317
    function run_env_as_bwrap_fakeroot(){
        local backend_command="$1"
        local backend_args="$2"
        local no_copy_files="$3"
        shift 3
        echo "run_env_as_bwrap_fakeroot($backend_command,$backend_args,$no_copy_files,$*)"
    }
    # shellcheck disable=SC2317
    function run_env_as_bwrap_user(){
        local backend_command="$1"
        local backend_args="$2"
        local no_copy_files="$3"
        shift 3
        echo "run_env_as_bwrap_user($backend_command,$backend_args,$no_copy_files,$*)"
    }
    # shellcheck disable=SC2317
    function is_env_installed(){
        return 0
    }
    # shellcheck disable=SC2317
    function create_wrappers(){
        :
    }
}

function test_help(){
    assertCommandSuccess main -h
    assertEquals "usage" "$(cat "$STDOUTF")"
    assertCommandSuccess main --help
    assertEquals "usage" "$(cat "$STDOUTF")"
}
function test_version(){
    assertCommandSuccess main -V
    assertEquals "version" "$(cat "$STDOUTF")"
    assertCommandSuccess main --version
    assertEquals "version" "$(cat "$STDOUTF")"
}
function test_build_image_env(){
    assertCommandSuccess main b
    assertEquals "build_image_env(false)" "$(cat "$STDOUTF")"
    assertCommandSuccess main build
    assertEquals "build_image_env(false)" "$(cat "$STDOUTF")"
    assertCommandSuccess main b -n
    assertEquals "build_image_env(true)" "$(cat "$STDOUTF")"
    assertCommandSuccess main build --disable-check
    assertEquals "build_image_env(true)" "$(cat "$STDOUTF")"
}

function test_create_wrappers(){
    # shellcheck disable=SC2317
    function create_wrappers(){
        local force=$1
        echo "create_wrappers($force)"
    }
    assertCommandSuccess main create-bin-wrappers
    assertEquals "create_wrappers(false)" "$(cat "$STDOUTF")"

    assertCommandSuccess main create-bin-wrappers --force
    assertEquals "create_wrappers(true)" "$(cat "$STDOUTF")"
}

function test_delete_env(){
    assertCommandSuccess main s -d
    assertEquals "delete_env" "$(cat "$STDOUTF")"
    assertCommandSuccess main setup --delete
    assertEquals "delete_env" "$(cat "$STDOUTF")"
}
function test_setup_env_from_file(){
    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandSuccess main s -i myimage
    assertEquals "setup_env_from_file(myimage)" "$(cat "$STDOUTF")"
    assertCommandSuccess main setup --from-file myimage
    assertEquals "setup_env_from_file(myimage)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 0
    }
    assertCommandFail main setup -i myimage
}

function test_setup_env(){
    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandSuccess main s
    assertEquals "setup_env()" "$(cat "$STDOUTF")"
    assertCommandSuccess main setup
    assertEquals "setup_env()" "$(cat "$STDOUTF")"
    assertCommandSuccess main s -a arm
    assertEquals "setup_env(arm)" "$(cat "$STDOUTF")"
    assertCommandSuccess main setup --arch arm
    assertEquals "setup_env(arm)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 0
    }
    assertCommandFail main setup -a arm
}

function test_run_env_as_proot_fakeroot(){
    assertCommandSuccess main p -f
    assertEquals "run_env_as_proot_fakeroot(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot --fakeroot
    assertEquals "run_env_as_proot_fakeroot(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main p -f -n
    assertEquals "run_env_as_proot_fakeroot(,,true,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main p -f --backend-command blah
    assertEquals "run_env_as_proot_fakeroot(blah,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot -f --backend-command blah
    assertEquals "run_env_as_proot_fakeroot(blah,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main proot -f -b "-b arg"
    assertEquals "run_env_as_proot_fakeroot(,-b arg,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot -f -b "-b arg" -- command -kv
    assertEquals "run_env_as_proot_fakeroot(,-b arg,false,command -kv)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot -f command --as
    assertEquals "run_env_as_proot_fakeroot(,,false,command --as)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot -f  -- command --as
    assertEquals "run_env_as_proot_fakeroot(,,false,command --as)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandFail main proot -f
}

function test_run_env_as_user(){
    assertCommandSuccess main proot
    assertEquals "run_env_as_proot_user(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main p -n
    assertEquals "run_env_as_proot_user(,,true,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main p --backend-command blah
    assertEquals "run_env_as_proot_user(blah,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot --backend-command blah
    assertEquals "run_env_as_proot_user(blah,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main proot -b "-b arg"
    assertEquals "run_env_as_proot_user(,-b arg,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot -b "-b arg" -- command -ll
    assertEquals "run_env_as_proot_user(,-b arg,false,command -ll)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot command -ls
    assertEquals "run_env_as_proot_user(,,false,command -ls)" "$(cat "$STDOUTF")"
    assertCommandSuccess main proot -- command -ls
    assertEquals "run_env_as_proot_user(,,false,command -ls)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandFail main proot
}

function test_run_env_as_groot(){
    assertCommandSuccess main g
    assertEquals "run_env_as_groot(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main g -n
    assertEquals "run_env_as_groot(,,true,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main g -b "-b arg"
    assertEquals "run_env_as_groot(,-b arg,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main g --backend-command blah
    assertEquals "run_env_as_groot(blah,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main groot --backend-command blah
    assertEquals "run_env_as_groot(blah,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main groot command
    assertEquals "run_env_as_groot(,,false,command)" "$(cat "$STDOUTF")"
    assertCommandSuccess main groot -- command
    assertEquals "run_env_as_groot(,,false,command)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandFail main groot
}

function test_run_env_as_chroot(){
    assertCommandSuccess main r
    assertEquals "run_env_as_chroot(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main r -b "-b arg"
    assertEquals "run_env_as_chroot(,-b arg,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main r --backend-command blah
    assertEquals "run_env_as_chroot(blah,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main root --backend-command blah
    assertEquals "run_env_as_chroot(blah,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main root command
    assertEquals "run_env_as_chroot(,,false,command)" "$(cat "$STDOUTF")"
    assertCommandSuccess main root -- command
    assertEquals "run_env_as_chroot(,,false,command)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandFail main root -f
}

function test_run_env_as_bwrap_fakeroot(){
    assertCommandSuccess main n -f
    assertEquals "run_env_as_bwrap_fakeroot(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -f
    assertEquals "run_env_as_bwrap_fakeroot(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -n -f
    assertEquals "run_env_as_bwrap_fakeroot(,,true,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main ns -f -b "-b arg"
    assertEquals "run_env_as_bwrap_fakeroot(,-b arg,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -f -b "-b arg" -- command -kv
    assertEquals "run_env_as_bwrap_fakeroot(,-b arg,false,command -kv)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -f command --as
    assertEquals "run_env_as_bwrap_fakeroot(,,false,command --as)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -f -- command --as
    assertEquals "run_env_as_bwrap_fakeroot(,,false,command --as)" "$(cat "$STDOUTF")"

    assertCommandSuccess main ns -f --backend-command blah
    assertEquals "run_env_as_bwrap_fakeroot(blah,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main -f --backend-command blah
    assertEquals "run_env_as_bwrap_fakeroot(blah,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main -f
    assertEquals "run_env_as_bwrap_fakeroot(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main -f
    assertEquals "run_env_as_bwrap_fakeroot(,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main -f -b "-b arg"
    assertEquals "run_env_as_bwrap_fakeroot(,-b arg,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main -f -b "-b arg" -- command -kv
    assertEquals "run_env_as_bwrap_fakeroot(,-b arg,false,command -kv)" "$(cat "$STDOUTF")"
    assertCommandSuccess main -f command --as
    assertEquals "run_env_as_bwrap_fakeroot(,,false,command --as)" "$(cat "$STDOUTF")"
    assertCommandSuccess main -f -- command --as
    assertEquals "run_env_as_bwrap_fakeroot(,,false,command --as)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandFail main ns -f
}

function test_run_env_as_bwrap_user(){
    assertCommandSuccess main n
    assertEquals "run_env_as_bwrap_user(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns
    assertEquals "run_env_as_bwrap_user(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -n
    assertEquals "run_env_as_bwrap_user(,,true,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main ns -b "-b arg"
    assertEquals "run_env_as_bwrap_user(,-b arg,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -b "-b arg" -- command -kv
    assertEquals "run_env_as_bwrap_user(,-b arg,false,command -kv)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns command --as
    assertEquals "run_env_as_bwrap_user(,,false,command --as)" "$(cat "$STDOUTF")"
    assertCommandSuccess main ns -- command --as
    assertEquals "run_env_as_bwrap_user(,,false,command --as)" "$(cat "$STDOUTF")"

    assertCommandSuccess main ns --backend-command blah
    assertEquals "run_env_as_bwrap_user(blah,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main --backend-command blah
    assertEquals "run_env_as_bwrap_user(blah,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main
    assertEquals "run_env_as_bwrap_user(,,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main
    assertEquals "run_env_as_bwrap_user(,,false,)" "$(cat "$STDOUTF")"

    assertCommandSuccess main -b "-b arg"
    assertEquals "run_env_as_bwrap_user(,-b arg,false,)" "$(cat "$STDOUTF")"
    assertCommandSuccess main -b "-b arg" -- command -kv
    assertEquals "run_env_as_bwrap_user(,-b arg,false,command -kv)" "$(cat "$STDOUTF")"
    assertCommandSuccess main command --as
    assertEquals "run_env_as_bwrap_user(,,false,command --as)" "$(cat "$STDOUTF")"
    assertCommandSuccess main -- command --as
    assertEquals "run_env_as_bwrap_user(,,false,command --as)" "$(cat "$STDOUTF")"

    # shellcheck disable=SC2317
    is_env_installed(){
        return 1
    }
    assertCommandFail main ns
}

function test_invalid_option(){
    assertCommandFail main --no-option
    assertCommandFail main n --no-option
    assertCommandFail main g --no-option
    assertCommandFail main r --no-option

    assertCommandFail main p --no-option

    assertCommandFail main b --no-option
    assertCommandFail main s --no-option
}

source "$(dirname "$0")"/../utils/shunit2
