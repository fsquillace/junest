#!/usr/bin/env bash
#
# This module contains all namespace functionalities for JuNest.
#
# http://man7.org/linux/man-pages/man7/namespaces.7.html
# http://man7.org/linux/man-pages/man2/unshare.2.html
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

CONFIG_PROC_FILE="/proc/config.gz"
CONFIG_BOOT_FILE="/boot/config-$($UNAME -r)"

function _is_user_namespace_enabled() {
    local config_file=""
    if [[ -e $CONFIG_PROC_FILE ]]
    then
        config_file=$CONFIG_PROC_FILE
    elif [[ -e $CONFIG_BOOT_FILE ]]
    then
        config_file=$CONFIG_BOOT_FILE
    else
        return $NOT_EXISTING_FILE
    fi

    if ! zgrep_cmd "CONFIG_USER_NS=y" $config_file
    then
        return $NO_CONFIG_FOUND
    fi
}

function run_env_as_user_with_namespace() {
    set +e
    _is_user_namespace_enabled
    case $? in
        $NOT_EXISTING_FILE) warn "Could not understand if user namespace is enabled. No config.gz file found. Proceeding anyway..." ;;
        $NO_CONFIG_FOUND) warn "User namespace is not enabled or Kernel too old. Proceeding anyway..." ;;
    esac
    set -e
}

function run_env_as_fakeroot_with_namespace() {
    die_on_status 1 "Not implemented yet"
}
