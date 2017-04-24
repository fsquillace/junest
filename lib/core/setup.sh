#!/usr/bin/env bash
#
# This module contains all setup functionalities for JuNest.
#
# Dependencies:
# - lib/utils/utils.sh
# - lib/core/common.sh
#
# vim: ft=sh

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
    if rm_cmd -rf ${JUNEST_HOME}
    then
        info "${NAME} deleted in ${JUNEST_HOME}"
    else
        error "Error: Cannot delete ${NAME} in ${JUNEST_HOME}"
    fi
}

