#!/usr/bin/env bash
#
# This module contains all chroot functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

function _run_env_as_xroot(){
    local cmd=$1
    local backend_args="$2"
    local no_copy_files="$3"
    shift 3

    check_same_arch

    local uid=$UID
    # SUDO_USER is more reliable compared to SUDO_UID
    [[ -z $SUDO_USER ]] || uid=$SUDO_USER:$SUDO_GID

    local args=()
    [[ "$1" != "" ]] && args=("-c" "$(insert_quotes_on_spaces "${@}")")

    # With chown the ownership of the files is assigned to the real user
    trap - QUIT EXIT ABRT KILL TERM INT
    # shellcheck disable=SC2064
    trap "[ -z $uid ] || chown_cmd -R ${uid} ${JUNEST_HOME};" EXIT QUIT ABRT TERM INT

    if ! $no_copy_files
    then
        copy_common_files
    fi

    # Resets PATH to avoid polluting with host related bin paths
    # shellcheck disable=SC2086
    PATH='' JUNEST_ENV=1 $cmd $backend_args "$JUNEST_HOME" "${DEFAULT_SH[@]}" "${args[@]}"
}

#######################################
# Run JuNest as real root via GRoot command.
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
#   UID (RO)                 : The user ID.
#   SUDO_USER (RO)           : The sudo user ID.
#   SUDO_GID (RO)            : The sudo group ID.
#   DEFAULT_SH (RO)          : Contains the default command to run in JuNest.
# Arguments:
#   backend_args ($1)        : The arguments to pass to backend program
#   no_copy_files ($2?)      : If false it will copy some files in /etc
#                              from host to JuNest environment.
#   cmd ($3-?)               : The command to run inside JuNest environment.
#                              Default command is defined by DEFAULT_SH variable.
# Returns:
#   $ARCHITECTURE_MISMATCH   : If host and JuNest architecture are different.
# Output:
#   -                        : The command output.
#######################################
function run_env_as_groot(){
    check_nested_env

    local backend_command="${1:-$GROOT}"
    local backend_args="$2"
    local no_copy_files="$3"
    shift 3

    provide_common_bindings
    local bindings=${RESULT}
    unset RESULT

    _run_env_as_xroot "$backend_command $bindings" "$backend_args" "$no_copy_files" "$@"
}

#######################################
# Run JuNest as real root via chroot command.
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
#   UID (RO)                 : The user ID.
#   SUDO_USER (RO)           : The sudo user ID.
#   SUDO_GID (RO)            : The sudo group ID.
#   DEFAULT_SH (RO)          : Contains the default command to run in JuNest.
# Arguments:
#   backend_args ($1)        : The arguments to pass to backend program
#   no_copy_files ($2?)      : If false it will copy some files in /etc
#                              from host to JuNest environment.
#   cmd ($3-?)               : The command to run inside JuNest environment.
#                              Default command is defined by DEFAULT_SH variable.
# Returns:
#   $ARCHITECTURE_MISMATCH   : If host and JuNest architecture are different.
# Output:
#   -                        : The command output.
#######################################
function run_env_as_chroot(){
    check_nested_env

    local backend_command="${1:-chroot_cmd}"
    local backend_args="$2"
    local no_copy_files="$3"
    shift 3

    _run_env_as_xroot "$backend_command" "$backend_args" "$no_copy_files" "$@"
}
