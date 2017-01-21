#!/usr/bin/env bash
#
# This module contains all core functionalities for JuNest.
#
# Dependencies:
# - lib/utils.sh
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

MAIN_REPO=https://dl.dropboxusercontent.com/u/42449030
ENV_REPO=${MAIN_REPO}/${CMD}
DEFAULT_MIRROR='https://mirrors.kernel.org/archlinux/$repo/os/$arch'

ORIGIN_WD=$(pwd)

################################ EXECUTABLES ##################################
# This section contains all the executables needed for JuNest to run properly.
# They are based on a fallback mechanism that tries to use the executable in
# different locations in the host OS.

# List of executables that are run inside JuNest:
SH=("/bin/sh" "--login")

# List of executables that are run in the host OS:
PROOT="${JUNEST_HOME}/opt/proot/proot-${ARCH}"
CHROOT=${JUNEST_BASE}/bin/jchroot
CLASSIC_CHROOT="chroot"
WGET="wget --no-check-certificate"
CURL="curl -L -J -O -k"
TAR=tar
CHOWN="chown"
LN=ln
RM=rm
MKDIR=mkdir
GETENT=getent
CP=cp

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
    $CHROOT "$@" || $CLASSIC_CHROOT "$@" || $LD_EXEC ${JUNEST_HOME}/usr/bin/chroot "$@"
}

################################# MAIN FUNCTIONS ##############################

#######################################
# Check if the JuNest system is installed in JUNEST_HOME.
#
# Globals:
#   JUNEST_HOME (RO)  : Contains the JuNest home directory.
# Arguments:
#   None
# Returns:
#   0                 : If JuNest is installed
#   1                 : If JuNest is not installed
# Output:
#   None
#######################################
function is_env_installed(){
    [ -d "$JUNEST_HOME" ] && [ "$(ls -A $JUNEST_HOME)" ] && return 0
    return 1
}


function _cleanup_build_directory(){
    local maindir=$1
    check_not_null "$maindir"
    builtin cd $ORIGIN_WD
    trap - QUIT EXIT ABRT KILL TERM INT
    rm_cmd -fr "$maindir"
}


function _prepare_build_directory(){
    local maindir=$1
    check_not_null "$maindir"
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "rm_cmd -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT KILL TERM INT
}


function _setup_env(){
    local imagepath=$1
    check_not_null "$imagepath"

    is_env_installed && die "Error: ${NAME} has been already installed in $JUNEST_HOME"

    mkdir_cmd -p "${JUNEST_HOME}"
    $TAR -zxpf ${imagepath} -C ${JUNEST_HOME}
    info "The default mirror URL is ${DEFAULT_MIRROR}."
    info "Remember to refresh the package databases from the server:"
    info "    pacman -Syy"
    info "${NAME} installed successfully"
}


#######################################
# Setup JuNest.
#
# Globals:
#   JUNEST_HOME (RO)      : The JuNest home directory in which JuNest needs
#                           to be installed.
#   ARCH (RO)             : The host architecture.
#   JUNEST_TEMPDIR (RO)   : The JuNest temporary directory for building
#                           the JuNest system from the image.
#   ENV_REPO (RO)         : URL of the site containing JuNest images.
#   NAME (RO)             : The JuNest name.
#   DEFAULT_MIRROR (RO)   : Arch Linux URL mirror.
# Arguments:
#   arch ($1?)            : The JuNest architecture image to download.
#                           Defaults to the host architecture
# Returns:
#   $NOT_AVAILABLE_ARCH   : If the architecture is not one of the available ones.
# Output:
#   None
#######################################
function setup_env(){
    local arch=${1:-$ARCH}
    contains_element $arch "${ARCH_LIST[@]}" || \
        die_on_status $NOT_AVAILABLE_ARCH "The architecture is not one of: ${ARCH_LIST[@]}"

    local maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t ${CMD}.XXXXXXXXXX)
    _prepare_build_directory $maindir

    info "Downloading ${NAME}..."
    builtin cd ${maindir}
    local imagefile=${CMD}-${arch}.tar.gz
    download_cmd ${ENV_REPO}/${imagefile}

    info "Installing ${NAME}..."
    _setup_env ${maindir}/${imagefile}

    _cleanup_build_directory ${maindir}
}

#######################################
# Setup JuNest from file.
#
# Globals:
#   JUNEST_HOME (RO)      : The JuNest home directory in which JuNest needs
#                           to be installed.
#   NAME (RO)             : The JuNest name.
#   DEFAULT_MIRROR (RO)   : Arch Linux URL mirror.
# Arguments:
#   imagefile ($1)        : The JuNest image file.
# Returns:
#   $NOT_EXISTING_FILE    : If the image file does not exist.
# Output:
#   None
#######################################
function setup_env_from_file(){
    local imagefile=$1
    check_not_null "$imagefile"
    [ ! -e ${imagefile} ] && die_on_status $NOT_EXISTING_FILE "Error: The ${NAME} image file ${imagefile} does not exist"

    info "Installing ${NAME} from ${imagefile}..."
    _setup_env ${imagefile}
}

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

    _copy_common_files

    _provide_common_bindings
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
    _copy_common_files
    _copy_file /etc/hosts.equiv
    _copy_file /etc/netgroup
    _copy_file /etc/networks
    # No need for localtime as it is setup during the image build
    #_copy_file /etc/localtime
    _copy_passwd_and_group

    _provide_common_bindings
    local bindings=${RESULT}
    unset RESULT

    _run_env_with_qemu "${bindings} -r ${JUNEST_HOME} $1" "${@:2}"
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
function _provide_common_bindings(){
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
function _copy_passwd_and_group(){
    # Enumeration of users/groups is disabled/limited depending on how nsswitch.conf
    # is configured.
    # Try to at least get the current user via `getent passwd $USER` since it uses
    # a more reliable and faster system call (getpwnam(3)).
    if ! getent_cmd passwd > ${JUNEST_HOME}/etc/passwd || \
        ! getent_cmd passwd ${USER} >> ${JUNEST_HOME}/etc/passwd
    then
        warn "getent command failed or does not exist. Binding directly from /etc/passwd."
        _copy_file /etc/passwd ${JUNEST_HOME}/etc/passwd
    fi

    if ! getent_cmd group > ${JUNEST_HOME}/etc/group
    then
        warn "getent command failed or does not exist. Binding directly from /etc/group."
        _copy_file /etc/group ${JUNEST_HOME}/etc/group
    fi
    return 0
}

function _copy_file() {
    local file="${1}"
    [[ -r "$file" ]] && cp_cmd "$file" "${JUNEST_HOME}/$file"
    return 0
}

function _copy_common_files() {
    _copy_file /etc/host.conf
    _copy_file /etc/hosts
    _copy_file /etc/nsswitch.conf
    _copy_file /etc/resolv.conf
    return 0
}

#######################################
# Remove an existing JuNest system.
#
# Globals:
#  JUNEST_HOME (RO)         : The JuNest home directory to remove.
# Arguments:
#  None
# Returns:
#  None
# Output:
#  None
#######################################
function delete_env(){
    ! ask "Are you sure to delete ${NAME} located in ${JUNEST_HOME}" "N" && return
    if mountpoint -q ${JUNEST_HOME}
    then
        info "There are mounted directories inside ${JUNEST_HOME}"
        if ! umount --force ${JUNEST_HOME}
        then
            error "Cannot umount directories in ${JUNEST_HOME}"
            die "Try to delete ${NAME} using root permissions"
        fi
    fi
    # the CA directories are read only and can be deleted only by changing the mod
    chmod -R +w ${JUNEST_HOME}/etc/ca-certificates
    if rm_cmd -rf ${JUNEST_HOME}/*
    then
        info "${NAME} deleted in ${JUNEST_HOME}"
    else
        error "Error: Cannot delete ${NAME} in ${JUNEST_HOME}"
    fi
}

function _check_package(){
    if ! pacman -Qq $1 > /dev/null
    then
        die "Package $1 must be installed"
    fi
}

function _install_from_aur(){
    local maindir=$1
    local pkgname=$2
    local installname=$3
    mkdir -p ${maindir}/packages/${pkgname}
    builtin cd ${maindir}/packages/${pkgname}
    $CURL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${pkgname}"
    [ -z "${installname}" ] || $CURL "https://aur.archlinux.org/cgit/aur.git/plain/${installname}?h=${pkgname}"
    makepkg -sfc
    sudo pacman --noconfirm --root ${maindir}/root -U ${pkgname}*.pkg.tar.xz
}

function build_image_env(){
    umask 022

    # The function must runs on ArchLinux with non-root privileges.
    (( EUID == 0 )) && \
        die "You cannot build with root privileges."

    _check_package arch-install-scripts
    _check_package gcc
    _check_package package-query
    _check_package git

    local disable_validation=$1
    local skip_root_tests=$2

    local maindir=$(TMPDIR=$JUNEST_TEMPDIR mktemp -d -t ${CMD}.XXXXXXXXXX)
    sudo mkdir -p ${maindir}/root
    trap - QUIT EXIT ABRT KILL TERM INT
    trap "sudo rm -rf ${maindir}; die \"Error occurred when installing ${NAME}\"" EXIT QUIT ABRT KILL TERM INT
    info "Installing pacman and its dependencies..."
    # The archlinux-keyring and libunistring are due to missing dependencies declaration in ARM archlinux
    # All the essential executables (ln, mkdir, chown, etc) are in coreutils
    # yaourt requires sed
    # localedef (called by locale-gen) requires gzip
    sudo pacstrap -G -M -d ${maindir}/root pacman coreutils libunistring archlinux-keyring sed gzip
    sudo bash -c "echo 'Server = $DEFAULT_MIRROR' >> ${maindir}/root/etc/pacman.d/mirrorlist"
    sudo mkdir -p ${maindir}/root/run/lock

    # AUR packages requires non-root user to be compiled. proot fakes the user to 10
    info "Compiling and installing yaourt..."
    _install_from_aur ${maindir} "package-query"
    _install_from_aur ${maindir} "yaourt"

    info "Install ${NAME} script..."
    sudo pacman --noconfirm --root ${maindir}/root -S git
    _install_from_aur ${maindir} "${CMD}-git" "${CMD}.install"
    sudo pacman --noconfirm --root ${maindir}/root -Rsn git

    info "Generating the locales..."
    # sed command is required for locale-gen
    sudo ln -sf /usr/share/zoneinfo/posix/UTC ${maindir}/root/etc/localtime
    sudo bash -c "echo 'en_US.UTF-8 UTF-8' >> ${maindir}/root/etc/locale.gen"
    sudo ${maindir}/root/opt/junest/bin/jchroot ${maindir}/root locale-gen
    sudo bash -c "echo LANG=\"en_US.UTF-8\" >> ${maindir}/root/etc/locale.conf"

    info "Setting up the pacman keyring (this might take a while!)..."
    sudo ${maindir}/root/opt/junest/bin/jchroot ${maindir}/root bash -c \
        "pacman-key --init; pacman-key --populate archlinux; [ -e /etc/pacman.d/gnupg/S.gpg-agent ] && gpg-connect-agent -S /etc/pacman.d/gnupg/S.gpg-agent killagent /bye"

    sudo rm ${maindir}/root/var/cache/pacman/pkg/*

    mkdir -p ${maindir}/output
    builtin cd ${maindir}/output
    local imagefile="${CMD}-${ARCH}.tar.gz"
    info "Compressing image to ${imagefile}..."
    sudo $TAR -zcpf ${imagefile} -C ${maindir}/root .

    if ! $disable_validation
    then
        mkdir -p ${maindir}/root_test
        $TAR -zxpf ${imagefile} -C "${maindir}/root_test"
        check_env "${maindir}/root_test" "${maindir}/root_test/opt/${CMD}/bin/${CMD}" $skip_root_tests
    fi

    sudo cp ${maindir}/output/${imagefile} ${ORIGIN_WD}

    builtin cd ${ORIGIN_WD}
    trap - QUIT EXIT ABRT KILL TERM INT
    sudo rm -fr "$maindir"
}

function check_env(){
    local testdir=$1
    local cmd=$2
    local skip_root_tests=$3
    info "Validating ${NAME} located in ${testdir} using the ${cmd} script..."
    echo "Server = ${DEFAULT_MIRROR}" >> ${testdir}/etc/pacman.d/mirrorlist
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -Syy

    # Check most basic executables work
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r pacman -Qi pacman 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -- pacman -Qi pacman 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -f -- pacman -Qi pacman 1> /dev/null
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r yogurt -V 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -- yogurt -V 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -f -- yogurt -V 1> /dev/null
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r /opt/proot/proot-$ARCH --help 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -- /opt/proot/proot-$ARCH --help 1> /dev/null
    JUNEST_HOME=${testdir} ${cmd} -f -- /opt/proot/proot-$ARCH --help 1> /dev/null

    local repo_package=tree
    info "Installing ${repo_package} package from official repo using proot..."
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -S ${repo_package}
    JUNEST_HOME=${testdir} ${cmd} tree
    JUNEST_HOME=${testdir} ${cmd} -f tree

    local repo_package=iftop
    info "Installing ${repo_package} package from official repo using root..."
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -S ${repo_package}
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r iftop -t -s 5

    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -S base-devel
    local aur_package=tcptraceroute
    info "Installing ${aur_package} package from AUR repo using proot..."
    JUNEST_HOME=${testdir} ${cmd} -f -- yogurt -A --noconfirm -S ${aur_package}
    $skip_root_tests || JUNEST_HOME=${testdir} sudo -E ${cmd} -r tcptraceroute localhost

    info "Removing the previous packages..."
    JUNEST_HOME=${testdir} ${cmd} -f pacman --noconfirm -Rsn tcptraceroute tree iftop

}
