#!/usr/bin/env bash
#
# This module contains all chroot functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

#######################################
# Run JuNest as real root.
#
# Globals:
#   JUNEST_HOME (RO)         : The JuNest home directory.
#   UID (RO)                 : The user ID.
#   SUDO_USER (RO)           : The sudo user ID.
#   SUDO_GID (RO)            : The sudo group ID.
#   SH (RO)                  : Contains the default command to run in JuNest.
# Arguments:
#   cmd ($@?)                : The command to run inside JuNest environment.
#                              Default command is defined by SH variable.
# Returns:
#   $ARCHITECTURE_MISMATCH   : If host and JuNest architecture are different.
# Output:
#   -                        : The command output.
#######################################
function run_env_as_root(){
    source ${JUNEST_HOME}/etc/junest/info
    [ "$JUNEST_ARCH" != "$ARCH" ] && \
        die_on_status $ARCHITECTURE_MISMATCH "The host system architecture is not correct: $ARCH != $JUNEST_ARCH"

    local uid=$UID
    # SUDO_USER is more reliable compared to SUDO_UID
    [ -z $SUDO_USER ] || uid=$SUDO_USER:$SUDO_GID

    local main_cmd="${SH[@]}"
    [ "$1" != "" ] && main_cmd="$(insert_quotes_on_spaces "$@")"

    # With chown the ownership of the files is assigned to the real user
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "[ -z $uid ] || chown_cmd -R ${uid} ${JUNEST_HOME};" EXIT QUIT ABRT KILL TERM INT

    JUNEST_ENV=1 chroot_cmd "$JUNEST_HOME" "${SH[@]}" "-c" "${main_cmd}"
}
