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

function _check_user_namespace() {
    set +e
    _is_user_namespace_enabled
    case $? in
        $NOT_EXISTING_FILE) warn "Could not understand if user namespace is enabled. No config.gz file found. Proceeding anyway..." ;;
        $NO_CONFIG_FOUND) warn "User namespace is not enabled or Kernel too old (<3.8). Proceeding anyway..." ;;
    esac
    set -e
}

function run_env_as_user_with_namespace() {
    local backend_args="$1"
    shift
    _check_user_namespace

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

    unshare_cmd --mount --user --map-root-user $GROOT $bindings $backend_args "$JUNEST_HOME"
}

function run_env_as_fakeroot_with_namespace() {
    local backend_args="$1"
    shift
    _check_user_namespace

    copy_common_files

  #mkdir -p "$chrootdir/$HOME"
  #mkdir -p "$chrootdir/run/lock"
  #chroot_add_mount --rbind /proc "$chrootdir/proc/"
  #chroot_add_mount --rbind /dev "$chrootdir/dev/"
  #chroot_add_mount --rbind /sys "$chrootdir/sys/"
  #chroot_add_mount --rbind /tmp "$chrootdir/tmp/"
  ## alternately create a new tmp istead of binding it:
  ##chroot_add_mount -t tmpfs tmp "$chrootdir/tmp/"
  #chroot_add_mount --rbind $HOME "$chrootdir/$HOME"
    provide_common_bindings
    local bindings=${RESULT}
    unset RESULT

    JUNEST_ENV=1 unshare_cmd --mount --user --map-root-user $GROOT $bindings $backend_args "$JUNEST_HOME"

}
