#!/bin/sh
# shellcheck disable=SC2154
# shellcheck disable=SC2034
# shellcheck disable=SC1091
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
PATH=/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin:${HOME}/.local/bin:"$PATH"

# The executable uname is essential in order to get the architecture
# of the host system, so a fallback mechanism cannot be used for it.
UNAME="uname"

ARCH_LIST="x86_64 x86 arm"
HOST_ARCH=$($UNAME -m)
# To check all available architectures look here:
# https://wiki.archlinux.org/index.php/PKGBUILD#arch
case "$HOST_ARCH" in
i686 | i386)
	ARCH="x86"
	LD_LIB="${JUNEST_HOME}/lib/ld-linux.so.2"
	;;
x86_64)
	ARCH="x86_64"
	LD_LIB="${JUNEST_HOME}/lib64/ld-linux-x86-64.so.2"
	;;
*arm* | aarch64)
	ARCH="arm"
	LD_LIB="${JUNEST_HOME}/lib/ld-linux-armhf.so.3"
	;;
*)
	die "Unknown architecture ${HOST_ARCH}"
	;;
esac

MAIN_REPO=https://link.storjshare.io/s/jvb5tgarnjtt565fffa44spvyuga/junest-repo
MAIN_REPO=https://pub-a2af2344e8554f6c807bc3db355ae622.r2.dev
ENV_REPO=${MAIN_REPO}/${CMD}
# shellcheck disable=SC2016
DEFAULT_MIRROR='https://mirror.rackspace.com/archlinux/$repo/os/$arch'

ORIGIN_WD=$(pwd)

################## EXECUTABLES ################

# This section contains all the executables needed for JuNest to run properly.
# They are based on a fallback mechanism that tries to use the executable in
# different locations in the host OS.

# List of executables that are run inside JuNest:
DEFAULT_SH="/bin/bash"

# List of executables that are run in the host OS:
BWRAP="${JUNEST_HOME}/usr/bin/bwrap"
PROOT="${JUNEST_HOME}/usr/bin/proot-${ARCH}"
GROOT="${JUNEST_HOME}/usr/bin/groot"
CLASSIC_CHROOT=chroot
WGET="wget --content-disposition --no-check-certificate"
CURL="curl -L -J -O -k"
TAR="tar"
CHOWN="chown"
LN="ln"
RM="rm"
MKDIR="mkdir"
GETENT="getent"
CP="cp"
ID="id"
# Used for checking user namespace in config.gz file
ZGREP="zgrep"
UNSHARE="unshare"

LD_EXEC="$LD_LIB --library-path ${JUNEST_HOME}/usr/lib:${JUNEST_HOME}/lib"

# The following functions attempt first to run the executable in the host OS.
# As a last hope they try to run the same executable available in the JuNest
# image.

ln_cmd() {
	$LN "$@" || $LD_EXEC "${JUNEST_HOME}"/usr/bin/$LN "$@"
}

getent_cmd() {
	$GETENT "$@" || $LD_EXEC "${JUNEST_HOME}"/usr/bin/$GETENT "$@"
}

cp_cmd() {
	$CP "$@" || $LD_EXEC "${JUNEST_HOME}"/usr/bin/$CP "$@"
}

rm_cmd() {
	$RM "$@" || $LD_EXEC "${JUNEST_HOME}"/usr/bin/$RM "$@"
}

chown_cmd() {
	$CHOWN "$@" || $LD_EXEC "${JUNEST_HOME}"/usr/bin/$CHOWN "$@"
}

mkdir_cmd() {
	$MKDIR "$@" || $LD_EXEC "${JUNEST_HOME}"/usr/bin/$MKDIR "$@"
}

zgrep_cmd() {
	# No need for LD_EXEC as zgrep is a POSIX shell script
	$ZGREP "$@" || "${JUNEST_HOME}"/usr/bin/$ZGREP "$@"
}

download_cmd() {
	$WGET "$@" || $CURL "$@"
}

chroot_cmd() {
	$CLASSIC_CHROOT "$@" || $LD_EXEC "${JUNEST_HOME}"/usr/bin/$CLASSIC_CHROOT "$@"
}

unshare_cmd() {
	# Most of the distros do not have the `unshare` command updated
	# with --user option available.
	# Hence, give priority to the `unshare` executable in JuNest image.
	# Also, unshare provides an environment in which /bin/sh maps to dash shell,
	# therefore it ignores all the remaining DEFAULT_SH arguments (i.e. --login) as
	# they are not supported by dash.
	if $LD_EXEC "${JUNEST_HOME}"/usr/bin/$UNSHARE --user "$DEFAULT_SH" "-c" ":"; then
		$LD_EXEC "${JUNEST_HOME}"/usr/bin/$UNSHARE "${@}"
	elif $UNSHARE --user "$DEFAULT_SH" "-c" ":"; then
		$UNSHARE "$@"
	else
		die "Error: Something went wrong while executing unshare command. Exiting"
	fi
}

bwrap_cmd() {
	if $LD_EXEC "$BWRAP" --dev-bind / / "$DEFAULT_SH" "-c" ":"; then
		$LD_EXEC "$BWRAP" "${@}"
	else
		die "Error: Something went wrong while executing bwrap command. Exiting"
	fi
}

proot_cmd() {
	shift
	# shellcheck disable=SC2086
	if ${PROOT} ${proot_args} "$DEFAULT_SH --login" "-c" ":"; then
		# shellcheck disable=SC2086
		${PROOT} ${proot_args} "${@}"
	elif PROOT_NO_SECCOMP=1 ${PROOT} ${proot_args} "$DEFAULT_SH --login" "-c" ":"; then
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
check_nested_env() {
	if [ "$JUNEST_ENV" = "1" ]; then
		die_on_status $NESTED_ENVIRONMENT "Error: Nested ${NAME} environments are not allowed"
	elif [ -n "$JUNEST_ENV" ] && [ "$JUNEST_ENV" != "0" ]; then
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
check_same_arch() {
	. "${JUNEST_HOME}"/etc/junest/info
	[ "$JUNEST_ARCH" != "$ARCH" ] &&
		die_on_status $ARCHITECTURE_MISMATCH "The host system architecture is not correct: $ARCH != $JUNEST_ARCH"
	return 0
}

#######################################
# Provide the proot common binding options for both normal user and fakeroot.
# The list of bindings can be found in `proot --help`. This excludes
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
provide_common_bindings() {
	RESULT=""
	for bind in "/dev" "/sys" "/proc" "/tmp" "$HOME" "/run/user/$($ID -u)"; do
		case "$re" in
		$bind)
			## [ -e "${BASH_REMATCH}" ] && RESULT="-b $bind $RESULT"
			RESULT="-b $bind $RESULT"
			;;
		*)
			[ -e "$bind" ] && RESULT="-b $bind $RESULT"
			;;
		esac
	done
	return 0
}

#######################################
# Build passwd and group files using getent command.
# If getent fails the fallbacks by copying the content from /etc/passwd
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
copy_passwd_and_group() {
	# Enumeration of users/groups is disabled/limited depending on how nsswitch.conf
	# is configured.
	# Try to at least get the current user via `getent passwd $USER` since it uses
	# a more reliable and faster system call (getpwnam(3)).
	if ! getent_cmd passwd >"${JUNEST_HOME}"/etc/passwd ||
		! getent_cmd passwd "${USER}" >>"${JUNEST_HOME}"/etc/passwd; then
		warn "getent command failed or does not exist. Binding directly from /etc/passwd."
		copy_file /etc/passwd
	fi

	if ! getent_cmd group >"${JUNEST_HOME}"/etc/group; then
		warn "getent command failed or does not exist. Binding directly from /etc/group."
		copy_file /etc/group
	fi
	return 0
}

copy_file() {
	# -f option ensure to remove destination file if it cannot be opened
	# https://github.com/fsquillace/junest/issues/284
	[ -r "$file" ] && cp_cmd -f "$file" "${JUNEST_HOME}/$file"
	return 0
}

copy_common_files() {
	copy_file /etc/host.conf
	copy_file /etc/hosts
	copy_file /etc/nsswitch.conf
	copy_file /etc/resolv.conf
	return 0
}

prepare_archlinux() {

	# shellcheck disable=SC2086
	$sudo pacman $pacman_options -Syy

	$sudo pacman-key --init

	case "$(uname -m)" in
	*"arm"*)
		# shellcheck disable=SC2086
		$sudo pacman $pacman_options -S archlinuxarm-keyring
		$sudo pacman-key --populate archlinuxarm
		;;
	*)
		# shellcheck disable=SC2086
		$sudo pacman $pacman_options -S archlinux-keyring
		$sudo pacman-key --populate archlinux
		;;
	esac

	# shellcheck disable=SC2086
	$sudo pacman $pacman_options -Su
}
