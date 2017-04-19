#!/bin/bash
source "$(dirname $0)/../utils/utils.sh"

JUNEST_BASE="$(readlink -f $(dirname $(readlink -f "$0"))/../..)"

# Disable the exiterr
set +e

function oneTimeSetUp(){
    setUpUnitTests
}

function setUp(){
    # Attempt to source the files under test to revert variable overrides
    source $JUNEST_BASE/bin/groot -h &> /dev/null
    set +e

    cwdSetUp
    mkdir -p chrootdir

    init_mocks
}

function tearDown(){
    cwdTearDown
}

## Mock functions ##
function init_mocks() {
    function usage(){
        echo "usage"
    }
    function is_user_root() {
        return 0
    }
    function chroot() {
        echo "chroot($@)"
    }
    function mountpoint() {
        echo "mountpoint($@)"
        # As default suppose the mountpoint does not exist
        return 1
    }
    function mountpoint_mock() {
        echo "mountpoint($@)"
    }
    function mount() {
        echo "mount($@)"
    }
    function umount() {
        echo "umount($@)"
    }
    function check_and_trap() {
        echo "check_and_trap($@)"
    }
}

function test_help(){
    assertCommandSuccess main -h
    assertEquals "usage" "$(cat $STDOUTF)"
    assertCommandSuccess main --help
    assertEquals "usage" "$(cat $STDOUTF)"
}
function test_version(){
    assertCommandSuccess main -V
    assertEquals "$NAME $(cat $JUNEST_BASE/VERSION)" "$(cat $STDOUTF)"
    assertCommandSuccess main --version
    assertEquals "$NAME $(cat $JUNEST_BASE/VERSION)" "$(cat $STDOUTF)"
}
function test_groot_no_root(){
    is_user_root() {
        return 1
    }
    assertCommandFailOnStatus $NO_ROOT_PRIVILEGES main
}
function test_groot_no_directory(){
    assertCommandFailOnStatus $NOT_EXISTING_FILE main no-directory
}
function test_groot_mountpoint_exist(){
    MOUNTPOINT=mountpoint_mock
    assertCommandSuccess main chrootdir
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_mountpoint_does_not_exist(){
    assertCommandSuccess main chrootdir
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_bind(){
    assertCommandSuccess main -b /tmp chrootdir
    [[ -d chrootdir/tmp ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(--bind /tmp chrootdir/tmp)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_bind_file(){
    touch file_src
    assertCommandSuccess main -b ${PWD}/file_src:/file_src chrootdir
    [[ -f chrootdir/file_src ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(--bind ${PWD}/file_src chrootdir/file_src)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_bind_not_existing_node(){
    assertCommandFailOnStatus $NOT_EXISTING_FILE main -b ${PWD}/file_src:/file_src chrootdir
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_bind_not_absolute_path_node(){
    touch file_src
    assertCommandFailOnStatus $NOT_ABSOLUTE_PATH main -b file_src:/file_src chrootdir
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_bind_guest_host(){
    assertCommandSuccess main -b /tmp:/home/tmp chrootdir
    [[ -d chrootdir/home/tmp ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(--bind /tmp chrootdir/home/tmp)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_multiple_bind(){
    assertCommandSuccess main -b /tmp:/home/tmp -b /dev chrootdir
    [[ -d chrootdir/home/tmp ]]
    assertEquals 0 $?
    [[ -d chrootdir/dev ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(--bind /tmp chrootdir/home/tmp)\nmount(--bind /dev chrootdir/dev)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_command(){
    assertCommandSuccess main chrootdir ls -la -h
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nchroot(chrootdir ls -la -h)")" "$(cat $STDOUTF)"
}
function test_groot_with_bind_and_command(){
    assertCommandSuccess main -b /tmp:/home/tmp -b /dev chrootdir ls -la -h
    [[ -d chrootdir/home/tmp ]]
    assertEquals 0 $?
    [[ -d chrootdir/dev ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(--bind /tmp chrootdir/home/tmp)\nmount(--bind /dev chrootdir/dev)\nchroot(chrootdir ls -la -h)")" "$(cat $STDOUTF)"
}
function test_groot_with_bind_no_umount(){
    assertCommandSuccess main -n chrootdir
    assertEquals "$(echo -e "mountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}
function test_groot_with_chroot_teardown(){
    MOUNTPOINT=mountpoint_mock
    echo -e "1 /home/mychroot/dev\n1 /home/mychroot/proc/fs1\n1 /home/mychroot\n1 /home/mychroot-no/dev\n1 /home/mychroot/dev/shm\n1 /home/mychroot/proc\n" > ./mounts
    MOUNTS_FILE=./mounts
    CHROOTDIR=/home/mychroot assertCommandSuccess chroot_teardown
    assertEquals "$(echo -e "mountpoint(-q /home/mychroot/proc/fs1)
umount(/home/mychroot/proc/fs1)
mountpoint(-q /home/mychroot/proc)
umount(/home/mychroot/proc)
mountpoint(-q /home/mychroot/dev/shm)
umount(/home/mychroot/dev/shm)
mountpoint(-q /home/mychroot/dev)
umount(/home/mychroot/dev)
umount(/home/mychroot)")" "$(cat $STDOUTF)"
}

function test_groot_with_chroot_teardown_umount_failure(){
    MOUNTPOINT=mountpoint_mock
    function umount() {
        echo "umount($@)"
        [[ "$1" == "/home/mychroot/dev/shm" ]] && return 128
        return 0
    }
    UMOUNT=umount
    echo -e "1 /home/mychroot/dev\n1 /home/mychroot/proc/fs1\n1 /home/mychroot\n1 /home/mychroot-no/dev\n1 /home/mychroot/dev/shm\n1 /home/mychroot/proc\n" > ./mounts
    MOUNTS_FILE=./mounts
    CHROOTDIR=/home/mychroot assertCommandFailOnStatus 128 chroot_teardown
    assertEquals "$(echo -e "mountpoint(-q /home/mychroot/proc/fs1)
umount(/home/mychroot/proc/fs1)
mountpoint(-q /home/mychroot/proc)
umount(/home/mychroot/proc)
mountpoint(-q /home/mychroot/dev/shm)
umount(/home/mychroot/dev/shm)
mountpoint(-q /home/mychroot/dev)
umount(/home/mychroot/dev)
umount(/home/mychroot)")" "$(cat $STDOUTF)"
}
function test_groot_with_chroot_teardown_with_trailing_slash(){
    MOUNTPOINT=mountpoint_mock
    echo -e "1 /home/mychroot/dev\n1 /home/mychroot/proc/fs1\n1 /home/mychroot\n1 /home/mychroot-no/dev\n1 /home/mychroot/dev/shm\n1 /home/mychroot/proc\n" > ./mounts
    MOUNTS_FILE=./mounts
    CHROOTDIR=/home/mychroot assertCommandSuccess chroot_teardown
    assertEquals "$(echo -e "mountpoint(-q /home/mychroot/proc/fs1)
umount(/home/mychroot/proc/fs1)
mountpoint(-q /home/mychroot/proc)
umount(/home/mychroot/proc)
mountpoint(-q /home/mychroot/dev/shm)
umount(/home/mychroot/dev/shm)
mountpoint(-q /home/mychroot/dev)
umount(/home/mychroot/dev)
umount(/home/mychroot)")" "$(cat $STDOUTF)"
}
function test_groot_with_chroot_teardown_mountpoint_failure(){
    mountpoint_mock() {
        echo "mountpoint($@)"
        [[ $2 == "/home/mychroot/dev/shm" ]] && return 128
        return 0
    }
    MOUNTPOINT=mountpoint_mock
    echo -e "1 /home/mychroot/dev\n1 /home/mychroot/proc/fs1\n1 /home/mychroot\n1 /home/mychroot-no/dev\n1 /home/mychroot/dev/shm\n1 /home/mychroot/proc\n" > ./mounts
    MOUNTS_FILE=./mounts
    CHROOTDIR=/home/mychroot assertCommandSuccess chroot_teardown
    assertEquals "$(echo -e "mountpoint(-q /home/mychroot/proc/fs1)
umount(/home/mychroot/proc/fs1)
mountpoint(-q /home/mychroot/proc)
umount(/home/mychroot/proc)
mountpoint(-q /home/mychroot/dev/shm)
mountpoint(-q /home/mychroot/dev)
umount(/home/mychroot/dev)
umount(/home/mychroot)")" "$(cat $STDOUTF)"
}

function test_groot_with_rbind(){
    assertCommandSuccess main -r -b /tmp chrootdir
    [[ -d chrootdir/tmp ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(--rbind /tmp chrootdir/tmp)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}

function test_groot_with_avoid_bind_proc(){
    assertCommandSuccess main -i -b /proc chrootdir
    [[ -d chrootdir/proc ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(proc chrootdir/proc -t proc)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}

function test_groot_with_avoid_bind_dev(){
    assertCommandSuccess main -i -b /dev chrootdir
    [[ -d chrootdir/dev ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(udev chrootdir/dev -t devtmpfs)\nmount(devpts /dev/pts -t devpts)\nmount(shm /dev/shm -t tmpfs)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}

function test_groot_with_avoid_bind_sys(){
    assertCommandSuccess main -i -b /sys chrootdir
    [[ -d chrootdir/sys ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(sys chrootdir/sys -t sysfs)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}

function test_groot_with_avoid_bind_run(){
    assertCommandSuccess main -i -b /run chrootdir
    [[ -d chrootdir/run ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(run chrootdir/run -t tmpfs)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}

function test_groot_with_avoid_bind_tmp(){
    assertCommandSuccess main -i -b /tmp chrootdir
    [[ -d chrootdir/tmp ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(tmp chrootdir/tmp -t tmpfs)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}

function test_groot_with_avoid_bind_combined(){
    assertCommandSuccess main -i -b /tmp -b /usr chrootdir
    cat $STDERRF
    [[ -d chrootdir/tmp ]]
    assertEquals 0 $?
    [[ -d chrootdir/usr ]]
    assertEquals 0 $?
    assertEquals "$(echo -e "check_and_trap(chroot_teardown QUIT EXIT ABRT KILL TERM INT)\nmountpoint(-q chrootdir)\nmount(--bind chrootdir chrootdir)\nmount(tmp chrootdir/tmp -t tmpfs)\nmount(--bind /usr chrootdir/usr)\nchroot(chrootdir)")" "$(cat $STDOUTF)"
}

source $(dirname $0)/../utils/shunit2
