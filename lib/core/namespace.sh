#!/usr/bin/env bash
#
# This module contains functionalities for accessing to JuNest via bubblewrap.
#
# https://github.com/containers/bubblewrap
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

# shellcheck disable=SC2027
COMMON_BWRAP_OPTION="--bind "$JUNEST_HOME" / --bind "$HOME" "$HOME" --bind /tmp /tmp --bind /sys /sys --bind /proc /proc --dev-bind-try /dev /dev --bind-try "/run/user/$($ID -u)" "/run/user/$($ID -u)" --unshare-user-try"
CONFIG_PROC_FILE="/proc/config.gz"
CONFIG_BOOT_FILE="/boot/config-$($UNAME -r)"
PROC_USERNS_CLONE_FILE="/proc/sys/kernel/unprivileged_userns_clone"
PROC_USERNS_FILE="/proc/$$/ns/user"

function _is_user_namespace_enabled() {
    if [[ -L $PROC_USERNS_FILE ]]
    then
        return 0
    fi

    if [[ -e $PROC_USERNS_CLONE_FILE ]]
    then
        # `-q` option in zgrep may cause a gzip: stdout: Broken pipe
        # Use redirect to /dev/null instead
        if zgrep_cmd "1" "$PROC_USERNS_CLONE_FILE" > /dev/null
        then
            return 0
        fi
    fi

    local config_file=""
    if [[ -e $CONFIG_PROC_FILE ]]
    then
        config_file=$CONFIG_PROC_FILE
    elif [[ -e $CONFIG_BOOT_FILE ]]
    then
        config_file=$CONFIG_BOOT_FILE
    else
        return "$NOT_EXISTING_FILE"
    fi

    # `-q` option in zgrep may cause a gzip: stdout: Broken pipe
    # Use redirect to /dev/null instead
    if ! zgrep_cmd "CONFIG_USER_NS=y" "$config_file" > /dev/null
    then
        return "$NO_CONFIG_FOUND"
    fi

    return "$UNPRIVILEGED_USERNS_DISABLED"
}

function _check_user_namespace() {
    set +e
    _is_user_namespace_enabled
    case $? in
        "$NOT_EXISTING_FILE") warn "Could not understand if user namespace is enabled. No config.gz file found. Proceeding anyway..." ;;
        "$NO_CONFIG_FOUND") warn "Unprivileged user namespace is disabled at kernel compile time or kernel too old (<3.8). Proceeding anyway..." ;;
        "$UNPRIVILEGED_USERNS_DISABLED") warn "Unprivileged user namespace disabled. Root permissions are required to enable it: sudo sysctl kernel.unprivileged_userns_clone=1" ;;
    esac
    set -e
}


#######################################
# Run JuNest as fakeroot via bwrap
#
# Globals:
#   JUNEST_HOME (RO)          : The JuNest home directory.
#   DEFAULT_SH (RO)           : Contains the default command to run in JuNest.
#   BWRAP (RO):               : The location of the bwrap binary.
# Arguments:
#   backend_args ($1)         : The arguments to pass to bwrap
#   no_copy_files ($2?)       : If false it will copy some files in /etc
#                               from host to JuNest environment.
#   cmd ($3-?)                : The command to run inside JuNest environment.
#                               Default command is defined by DEFAULT_SH variable.
# Returns:
#   $ARCHITECTURE_MISMATCH    : If host and JuNest architecture are different.
#   $ROOT_ACCESS_ERROR        : If the user is the real root.
# Output:
#   -                         : The command output.
#######################################
function run_env_as_bwrap_fakeroot(){
    check_nested_env

    local backend_command="${1:-$BWRAP}"
    local backend_args="$2"
    local no_copy_files="$3"
    shift 3

    _check_user_namespace

    check_same_arch

    if ! $no_copy_files
    then
        copy_common_files
    fi

    local args=()
    [[ "$1" != "" ]] && args=("-c" "$(insert_quotes_on_spaces "${@}")")

    # Fix PATH to /usr/bin to make sudo working and avoid polluting with host related bin paths
    # shellcheck disable=SC2086
    PATH="/usr/bin" BWRAP="${backend_command}" JUNEST_ENV=1 bwrap_cmd $COMMON_BWRAP_OPTION --cap-add ALL --uid 0 --gid 0 $backend_args sudo "${DEFAULT_SH[@]}" "${args[@]}"
}


#######################################
# Run JuNest as normal user via bwrap.
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
#   DEFAULT_SH (RO)          : Contains the default command to run in JuNest.
#   BWRAP (RO):               : The location of the bwrap binary.
# Arguments:
#   backend_args ($1)        : The arguments to pass to bwrap
#   no_copy_files ($2?)      : If false it will copy some files in /etc
#                              from host to JuNest environment.
#   cmd ($3-?)               : The command to run inside JuNest environment.
#                              Default command is defined by DEFAULT_SH variable.
# Returns:
#   $ARCHITECTURE_MISMATCH   : If host and JuNest architecture are different.
# Output:
#   -                        : The command output.
#######################################
function run_env_as_bwrap_user() {
    check_nested_env

    local backend_command="${1:-$BWRAP}"
    local backend_args="$2"
    local no_copy_files="$3"
    shift 3

    _check_user_namespace

    check_same_arch

    if ! $no_copy_files
    then
        copy_common_files
        copy_file /etc/hosts.equiv
        copy_file /etc/netgroup
        copy_file /etc/networks
        # No need for localtime as it is setup during the image build
        #copy_file /etc/localtime
        copy_passwd_and_group
    fi

    local args=()
    [[ "$1" != "" ]] && args=("-c" "$(insert_quotes_on_spaces "${@}")")

    # Resets PATH to avoid polluting with host related bin paths
    # shellcheck disable=SC2086
    PATH='' BWRAP="${backend_command}" JUNEST_ENV=1 bwrap_cmd $COMMON_BWRAP_OPTION $backend_args "${DEFAULT_SH[@]}" "${args[@]}"
}




