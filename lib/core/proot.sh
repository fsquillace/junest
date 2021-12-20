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
    local backend_command="${1:-$PROOT}"
    local backend_args="$2"
    shift 2

    local args=()
    [[ "$1" != "" ]] && args=("-c" "$(insert_quotes_on_spaces "${@}")")

    PROOT="${backend_command}" JUNEST_ENV=1 proot_cmd "${backend_args}" "${DEFAULT_SH[@]}" "${args[@]}"
}

function _run_env_with_qemu(){
    local backend_command="$1"
    local backend_args="$2"
    shift 2

    source ${JUNEST_HOME}/etc/junest/info

    if [ "$JUNEST_ARCH" != "$ARCH" ]
    then
        local qemu_bin="qemu-$JUNEST_ARCH-static-$ARCH"
        local qemu_symlink="/tmp/${qemu_bin}-$RANDOM"
        trap - QUIT EXIT ABRT KILL TERM INT
        trap "[ -e ${qemu_symlink} ] && rm_cmd -f ${qemu_symlink}" EXIT QUIT ABRT KILL TERM INT

        warn "Emulating $NAME via QEMU..."
        [ -e ${qemu_symlink} ] || \
            ln_cmd -s ${JUNEST_HOME}/bin/${qemu_bin} ${qemu_symlink}
        backend_args="-q ${qemu_symlink} $backend_args"
    fi

    _run_env_with_proot "${backend_command}" "$backend_args" "${@}"
}

#######################################
# Run JuNest as fakeroot.
#
# Globals:
#   JUNEST_HOME (RO)          : The JuNest home directory.
#   EUID (RO)                 : The user ID.
#   DEFAULT_SH (RO)           : Contains the default command to run in JuNest.
# Arguments:
#   backend_args ($1)         : The arguments to pass to proot
#   no_copy_files ($2?)      : If false it will copy some files in /etc
#                              from host to JuNest environment.
#   cmd ($3-?)                : The command to run inside JuNest environment.
#                              Default command is defined by DEFAULT_SH variable.
# Returns:
#   $ROOT_ACCESS_ERROR        : If the user is the real root.
# Output:
#   -                         : The command output.
#######################################
function run_env_as_proot_fakeroot(){
    (( EUID == 0 )) && \
        die_on_status $ROOT_ACCESS_ERROR "You cannot access with root privileges. Use --groot option instead."
    check_nested_env

    local backend_command="$1"
    local backend_args="$2"
    local no_copy_files="$3"
    shift 3

    if ! $no_copy_files
    then
        copy_common_files
    fi

    provide_common_bindings
    local bindings=${RESULT}
    unset RESULT

    # An alternative is via -S option:
    #_run_env_with_qemu "-S ${JUNEST_HOME} $1" "${@:2}"
    _run_env_with_qemu "$backend_command" "-0 ${bindings} -r ${JUNEST_HOME} $backend_args" "$@"
}

#######################################
# Run JuNest as normal user.
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
#   EUID (RO)                : The user ID.
#   DEFAULT_SH (RO)          : Contains the default command to run in JuNest.
# Arguments:
#   backend_args ($1)        : The arguments to pass to proot
#   no_copy_files ($2?)      : If false it will copy some files in /etc
#                              from host to JuNest environment.
#   cmd ($3-?)               : The command to run inside JuNest environment.
#                              Default command is defined by DEFAULT_SH variable.
# Returns:
#   $ROOT_ACCESS_ERROR       : If the user is the real root.
# Output:
#   -                        : The command output.
#######################################
function run_env_as_proot_user(){
    (( EUID == 0 )) && \
        die_on_status $ROOT_ACCESS_ERROR "You cannot access with root privileges. Use --groot option instead."
    check_nested_env

    local backend_command="$1"
    local backend_args="$2"
    local no_copy_files="$3"
    shift 3

    if ! $no_copy_files
    then
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
    fi

    provide_common_bindings
    local bindings=${RESULT}
    unset RESULT

    _run_env_with_qemu "$backend_command" "${bindings} -r ${JUNEST_HOME} $backend_args" "$@"
}
