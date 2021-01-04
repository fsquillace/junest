#!/usr/bin/env bash
#
# This module contains all common functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
#
# vim: ft=sh

NAME='JuNest'
CMD='junest'
DESCRIPTION='The Arch Linux based distro that runs upon any Linux distros without root access'

NOT_AVAILABLE_ARCH=102
NOT_EXISTING_FILE=103
ARCHITECTURE_MISMATCH=104
ROOT_ACCESS_ERROR=105
NESTED_ENVIRONMENT=106
VARIABLE_NOT_SET=107
NO_CONFIG_FOUND=108
UNPRIVILEGED_USERNS_DISABLED=109

JUNEST_HOME=${JUNEST_HOME:-~/.${CMD}}
JUNEST_TEMPDIR=${JUNEST_TEMPDIR:-/tmp}

# The update of the variable PATH ensures that the executables are
# found on different locations
PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin

# The executable uname is essential in order to get the architecture
# of the host system, so a fallback mechanism cannot be used for it.
UNAME=uname

ARCH_LIST=('x86_64' 'x86' 'arm')
HOST_ARCH=$($UNAME -m)
# To check all available architectures look here:
# https://wiki.archlinux.org/index.php/PKGBUILD#arch
if [[ $HOST_ARCH == "i686" ]] || [[ $HOST_ARCH == "i386" ]]
then
    ARCH="x86"
    LD_LIB="${JUNEST_HOME}/lib/ld-linux.so.2"
elif [[ $HOST_ARCH == "x86_64" ]]
then
    ARCH="x86_64"
    LD_LIB="${JUNEST_HOME}/lib64/ld-linux-x86-64.so.2"
elif [[ $HOST_ARCH =~ .*(arm).* ]] || [[ $HOST_ARCH == "aarch64" ]]
then
    ARCH="arm"
    LD_LIB="${JUNEST_HOME}/lib/ld-linux-armhf.so.3"
else
    die "Unknown architecture ${HOST_ARCH}"
fi

MAIN_REPO=https://s3-eu-west-1.amazonaws.com/${CMD}-repo
ENV_REPO=${MAIN_REPO}/${CMD}
DEFAULT_MIRROR='https://mirrors.kernel.org/archlinux/$repo/os/$arch'

ORIGIN_WD=$(pwd)

################## EXECUTABLES ################

# This section contains all the executables needed for JuNest to run properly.
# They are based on a fallback mechanism that tries to use the executable in
# different locations in the host OS.

# List of executables that are run inside JuNest:
DEFAULT_SH=("/bin/sh" "--login")

# List of executables that are run in the host OS:
PROOT="${JUNEST_HOME}/usr/bin/proot-${ARCH}"
GROOT="${JUNEST_HOME}/usr/bin/groot"
CLASSIC_CHROOT=chroot
WGET="wget --no-check-certificate"
CURL="curl -L -J -O -k"
TAR=tar
CHOWN="chown"
LN=ln
RM=rm
MKDIR=mkdir
GETENT=getent
CP=cp
# Used for checking user namespace in config.gz file
ZGREP=zgrep
UNSHARE=unshare
BWRAP=bwrap

LD_EXEC="$LD_LIB --library-path ${JUNEST_HOME}/usr/lib:${JUNEST_HOME}/lib"

# The following functions attempt first to run the executable in the host OS.
# As a last hope they try to run the same executable available in the JuNest
# image.

function ln_cmd(){
    $LN "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$LN "$@"
}

function getent_cmd(){
    $GETENT "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$GETENT "$@"
}

function cp_cmd(){
    $CP "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$CP "$@"
}

function rm_cmd(){
    $RM "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$RM "$@"
}

function chown_cmd(){
    $CHOWN "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$CHOWN "$@"
}

function mkdir_cmd(){
    $MKDIR "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$MKDIR "$@"
}

function zgrep_cmd(){
    # No need for LD_EXEC as zgrep is a POSIX shell script
    $ZGREP "$@" || ${JUNEST_HOME}/usr/bin/$ZGREP "$@"
}

function download_cmd(){
    $WGET "$@" || $CURL "$@"
}

function chroot_cmd(){
    $CLASSIC_CHROOT "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$CLASSIC_CHROOT "$@"
}

function unshare_cmd(){
    # Most of the distros do not have the `unshare` command updated
    # with --user option available.
    # Hence, give priority to the `unshare` executable in JuNest image.
    # Also, unshare provides an environment in which /bin/sh maps to dash shell,
    # therefore it ignores all the remaining DEFAULT_SH arguments (i.e. --login) as
    # they are not supported by dash.
    if $LD_EXEC ${JUNEST_HOME}/usr/bin/$UNSHARE --user "${DEFAULT_SH[0]}" "-c" ":"
    then
        $LD_EXEC ${JUNEST_HOME}/usr/bin/$UNSHARE "${@}"
    elif $UNSHARE --user "${DEFAULT_SH[0]}" "-c" ":"
    then
        $UNSHARE "$@"
    else
        die "Error: Something went wrong while executing unshare command. Exiting"
    fi
}

function bwrap_cmd(){
    if $LD_EXEC ${JUNEST_HOME}/usr/bin/$BWRAP --dev-bind / / "${DEFAULT_SH[0]}" "-c" ":"
    then
        $LD_EXEC ${JUNEST_HOME}/usr/bin/$BWRAP "${@}"
    else
        die "Error: Something went wrong while executing bwrap command. Exiting"
    fi
}

function proot_cmd(){
    local proot_args="$1"
    shift
    if ${PROOT} ${proot_args} "${DEFAULT_SH[@]}" "-c" ":"
    then
        ${PROOT} ${proot_args} "${@}"
    elif PROOT_NO_SECCOMP=1 ${PROOT} ${proot_args} "${DEFAULT_SH[@]}" "-c" ":"
    then
        warn "Warn: Proot is not properly working. Disabling SECCOMP and expect the application to run slowly in particular when it uses syscalls intensively."
        warn "Try to use Linux namespace instead as it is more reliable: junest ns"
        PROOT_NO_SECCOMP=1 ${PROOT} ${proot_args} "${@}"
    else
        die "Error: Something went wrong with proot command. Exiting"
    fi
}

############## COMMON FUNCTIONS ###############

#######################################
# Check if the executable is being running inside a JuNest environment.
#
# Globals:
#   JUNEST_ENV (RO)           : The boolean junest env check
#   NESTED_ENVIRONMENT (RO)   : The nest env exception
#   VARIABLE_NOT_SET (RO)     : The var not set exception
#   NAME (RO)                 : The JuNest name
# Arguments:
#   None
# Returns:
#   VARIABLE_NOT_SET          : If no JUNEST_ENV is not properly set
#   NESTED_ENVIRONMENT        : If the script is executed inside JuNest env
# Output:
#   None
#######################################
function check_nested_env() {
    if [[ $JUNEST_ENV == "1" ]]
    then
        die_on_status $NESTED_ENVIRONMENT "Error: Nested ${NAME} environments are not allowed"
    elif [[ ! -z $JUNEST_ENV ]] && [[ $JUNEST_ENV != "0" ]]
    then
        die_on_status $VARIABLE_NOT_SET "The variable JUNEST_ENV is not properly set"
    fi
}

#######################################
# Check if the architecture between Host OS and Guest OS is the same.
#
# Globals:
#   JUNEST_HOME (RO)           : The JuNest home path.
#   ARCHITECTURE_MISMATCH (RO) : The arch mismatch exception
#   ARCH (RO)                  : The host OS arch
#   JUNEST_ARCH (RO)           : The JuNest arch
# Arguments:
#   None
# Returns:
#   ARCHITECTURE_MISMATCH      : If arch between host and guest is not the same
# Output:
#   None
#######################################
function check_same_arch() {
    source ${JUNEST_HOME}/etc/junest/info
    [ "$JUNEST_ARCH" != "$ARCH" ] && \
        die_on_status $ARCHITECTURE_MISMATCH "The host system architecture is not correct: $ARCH != $JUNEST_ARCH"
    return 0
}

#######################################
# Provide the proot common binding options for both normal user and fakeroot.
# The list of bindings can be found in `proot --help`. This function excludes
# /etc/mtab file so that it will not give conflicts with the related
# symlink in the image.
#
# Globals:
#   HOME (RO)       : The home directory.
#   RESULT (WO)     : Contains the binding options.
# Arguments:
#   None
# Returns:
#   None
# Output:
#   None
#######################################
function provide_common_bindings(){
    RESULT=""
    local re='(.*):.*'
    for bind in "/dev" "/sys" "/proc" "/tmp" "$HOME"
    do
        if [[ $bind =~ $re ]]
        then
            [ -e "${BASH_REMATCH[1]}" ] && RESULT="-b $bind $RESULT"
        else
            [ -e "$bind" ] && RESULT="-b $bind $RESULT"
        fi
    done
    return 0
}

#######################################
# Build passwd and group files using getent command.
# If getent fails the function fallbacks by copying the content from /etc/passwd
# and /etc/group.
#
# The generated passwd and group will be stored in $JUNEST_HOME/etc/junest.
#
# Globals:
#  JUNEST_HOME (RO)      : The JuNest home directory.
# Arguments:
#  None
# Returns:
#  None
# Output:
#  None
#######################################
function copy_passwd_and_group(){
    # Enumeration of users/groups is disabled/limited depending on how nsswitch.conf
    # is configured.
    # Try to at least get the current user via `getent passwd $USER` since it uses
    # a more reliable and faster system call (getpwnam(3)).
    if ! getent_cmd passwd > ${JUNEST_HOME}/etc/passwd || \
        ! getent_cmd passwd ${USER} >> ${JUNEST_HOME}/etc/passwd
    then
        warn "getent command failed or does not exist. Binding directly from /etc/passwd."
        copy_file /etc/passwd ${JUNEST_HOME}/etc/passwd
    fi

    if ! getent_cmd group > ${JUNEST_HOME}/etc/group
    then
        warn "getent command failed or does not exist. Binding directly from /etc/group."
        copy_file /etc/group ${JUNEST_HOME}/etc/group
    fi
    return 0
}

function copy_file() {
    local file="${1}"
    [[ -r "$file" ]] && cp_cmd "$file" "${JUNEST_HOME}/$file"
    return 0
}

function copy_common_files() {
    copy_file /etc/host.conf
    copy_file /etc/hosts
    copy_file /etc/nsswitch.conf
    copy_file /etc/resolv.conf
    return 0
}
