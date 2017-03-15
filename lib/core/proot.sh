#!/usr/bin/env bash
#
# This module contains all proot functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

function _run_env_with_proot(){
    local proot_args="$1"
    shift

    if [ "$1" != "" ]
    then
        JUNEST_ENV=1 proot_cmd "${proot_args}" "${SH[@]}" "-c" "$(insert_quotes_on_spaces "${@}")"
    else
        JUNEST_ENV=1 proot_cmd "${proot_args}" "${SH[@]}"
    fi
}

function _run_env_with_qemu(){
    local proot_args="$1"
    source ${JUNEST_HOME}/etc/junest/info

    if [ "$JUNEST_ARCH" != "$ARCH" ]
    then
        local qemu_bin="qemu-$JUNEST_ARCH-static-$ARCH"
        local qemu_symlink="/tmp/${qemu_bin}-$RANDOM"
        trap - QUIT EXIT ABRT KILL TERM INT
        trap "[ -e ${qemu_symlink} ] && rm_cmd -f ${qemu_symlink}" EXIT QUIT ABRT KILL TERM INT

        warn "Emulating $NAME via QEMU..."
        [ -e ${qemu_symlink} ] || \
            ln_cmd -s ${JUNEST_HOME}/opt/qemu/${qemu_bin} ${qemu_symlink}
        proot_args="-q ${qemu_symlink} $proot_args"
    fi
    shift
    _run_env_with_proot "$proot_args" "${@}"
}

#######################################
# Run JuNest as fakeroot.
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
#   EUID (RO)                : The user ID.
#   SH (RO)                  : Contains the default command to run in JuNest.
# Arguments:
#   cmd ($@?)                : The command to run inside JuNest environment.
#                              Default command is defined by SH variable.
# Returns:
#   $ROOT_ACCESS_ERROR       : If the user is the real root.
# Output:
#   -                        : The command output.
#######################################
function run_env_as_fakeroot(){
    (( EUID == 0 )) && \
        die_on_status $ROOT_ACCESS_ERROR "You cannot access with root privileges. Use --root option instead."

    copy_common_files

    provide_common_bindings
    local bindings=${RESULT}
    unset RESULT

    # An alternative is via -S option:
    #_run_env_with_qemu "-S ${JUNEST_HOME} $1" "${@:2}"
    _run_env_with_qemu "-0 ${bindings} -r ${JUNEST_HOME} $1" "${@:2}"
}

#######################################
# Run JuNest as normal user.
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
#   EUID (RO)                : The user ID.
#   SH (RO)                  : Contains the default command to run in JuNest.
# Arguments:
#   cmd ($@?)                : The command to run inside JuNest environment.
#                              Default command is defined by SH variable.
# Returns:
#   $ROOT_ACCESS_ERROR       : If the user is the real root.
# Output:
#   -                        : The command output.
#######################################
function run_env_as_user(){
    (( EUID == 0 )) && \
        die_on_status $ROOT_ACCESS_ERROR "You cannot access with root privileges. Use --root option instead."

    # Files to bind are visible in `proot --help`.
    # This function excludes /etc/mtab file so that
    # it will not give conflicts with the related
    # symlink in the Arch Linux image.
    copy_common_files
    copy_file /etc/hosts.equiv
    copy_file /etc/netgroup
    copy_file /etc/networks
    # No need for localtime as it is setup during the image build
    #copy_file /etc/localtime
    copy_passwd_and_group

    provide_common_bindings
    local bindings=${RESULT}
    unset RESULT

    _run_env_with_qemu "${bindings} -r ${JUNEST_HOME} $1" "${@:2}"
}
