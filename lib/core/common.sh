#!/usr/bin/env bash
#
# This module contains all common functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
#
# vim: ft=sh

set -e

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

if [ "$JUNEST_ENV" == "1" ]
then
    die_on_status $NESTED_ENVIRONMENT "Error: Nested ${NAME} environments are not allowed"
elif [ ! -z $JUNEST_ENV ] && [ "$JUNEST_ENV" != "0" ]
then
    die_on_status $VARIABLE_NOT_SET "The variable JUNEST_ENV is not properly set"
fi

[ -z ${JUNEST_HOME} ] && JUNEST_HOME=~/.${CMD}
[ -z ${JUNEST_BASE} ] && JUNEST_BASE=${JUNEST_HOME}/opt/junest
if [ -z ${JUNEST_TEMPDIR} ] || [ ! -d ${JUNEST_TEMPDIR} ]
then
    JUNEST_TEMPDIR=/tmp
fi

# The update of the variable PATH ensures that the executables are
# found on different locations
PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH

# The executable uname is essential in order to get the architecture
# of the host system, so a fallback mechanism cannot be used for it.
UNAME=uname

ARCH_LIST=('x86_64' 'x86' 'arm')
HOST_ARCH=$($UNAME -m)
if [ $HOST_ARCH == "i686" ] || [ $HOST_ARCH == "i386" ]
then
    ARCH="x86"
    LD_LIB="${JUNEST_HOME}/lib/ld-linux.so.2"
elif [ $HOST_ARCH == "x86_64" ]
then
    ARCH="x86_64"
    LD_LIB="${JUNEST_HOME}/lib64/ld-linux-x86-64.so.2"
elif [[ $HOST_ARCH =~ .*(arm).* ]]
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
SH=("/bin/sh" "--login")

# List of executables that are run in the host OS:
PROOT="${JUNEST_HOME}/opt/proot/proot-${ARCH}"
JCHROOT=${JUNEST_BASE}/bin/jchroot
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

LD_EXEC="$LD_LIB --library-path ${JUNEST_HOME}/usr/lib:${JUNEST_HOME}/lib"

# The following functions attempt first to run the executable in the host OS.
# As a last hope they try to run the same executable available in the JuNest
# image.

function ln_cmd(){
    $LN $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$LN $@
}

function getent_cmd(){
    $GETENT $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$GETENT $@
}

function cp_cmd(){
    $CP $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$CP $@
}

function rm_cmd(){
    $RM $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$RM $@
}

function chown_cmd(){
    $CHOWN $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$CHOWN $@
}

function mkdir_cmd(){
    $MKDIR $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$MKDIR $@
}

function zgrep_cmd(){
    $ZGREP $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$ZGREP $@
}

function unshare_cmd(){
    $UNSHARE $@ || $LD_EXEC ${JUNEST_HOME}/usr/bin/$UNSHARE $@
}

function proot_cmd(){
    local proot_args="$1"
    shift
    if ${PROOT} ${proot_args} "${SH[@]}" "-c" ":"
    then
        ${PROOT} ${proot_args} "${@}"
    elif PROOT_NO_SECCOMP=1 ${PROOT} ${proot_args} "${SH[@]}" "-c" ":"
    then
        PROOT_NO_SECCOMP=1 ${PROOT} ${proot_args} "${@}"
    else
        die "Error: Check if the ${CMD} arguments are correct and if the kernel is too old use the option ${CMD} -p \"-k 3.10\""
    fi
}

function download_cmd(){
    $WGET $@ || $CURL $@
}

function chroot_cmd(){
    $JCHROOT "$@" || $CLASSIC_CHROOT "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/$CLASSIC_CHROOT "$@"
}

############## COMMON FUNCTIONS ###############

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
