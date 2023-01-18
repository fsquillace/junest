#!/bin/sh

NULL_EXCEPTION=11
WRONG_ANSWER=33

#######################################
# Check if the argument is null.
#
# Globals:
#   None
# Arguments:
#   argument ($1)    : Argument to check.
# Returns:
#   0                : If argument is not null.
#   NULL_EXCEPTION   : If argument is null.
# Output:
#   None
#######################################
check_not_null() {
	[ -z "$1" ] && {
		error "Error: null argument $1"
		return $NULL_EXCEPTION
	}
	return 0
}

#######################################
# Redirect message to stderr.
#
# Globals:
#   None
# Arguments:
#   msg ($@): Message to print.
# Returns:
#   None
# Output:
#   Message printed to stderr.
#######################################
echoerr() {
	printf '%b\n' "$@" 1>&2
}

#######################################
# Print an error message to stderr and exit program.
#
# Globals:
#   None
# Arguments:
#   msg ($@)   : Message to print.
# Returns:
#   1          : The unique exit status printed.
# Output:
#   Message printed to stderr.
#######################################
die() {
	error "$@"
	exit 1
}

#######################################
# Print an error message to stderr and exit program with a given status.
#
# Globals:
#   None
# Arguments:
#   status ($1)     : The exit status to use.
#   msg ($2-)       : Message to print.
# Returns:
#   $?              : The $status exit status.
# Output:
#   Message printed to stderr.
#######################################
die_on_status() {
	status=$1
	shift
	error "$@"
	exit "$status"
}

#######################################
# Print an error message to stderr.
#
# Globals:
#   None
# Arguments:
#   msg ($@): Message to print.
# Returns:
#   None
# Output:
#   Message printed to stderr.
#######################################
error() {
	echoerr "\033[1;31m$*\033[0m"
}

#######################################
# Print a warn message to stderr.
#
# Globals:
#   None
# Arguments:
#   msg ($@): Message to print.
# Returns:
#   None
# Output:
#   Message printed to stderr.
#######################################
warn() {
	# $@: msg (mandatory) - str: Message to print
	echoerr "\033[1;33m$*\033[0m"
}

#######################################
# Print an info message to stdout.
#
# Globals:
#   None
# Arguments:
#   msg ($@): Message to print.
# Returns:
#   None
# Output:
#   Message printed to stdout.
#######################################
info() {
	printf '%b\n' "\033[1;36m$*\033[0m"
}

#######################################
# Ask a question and wait to receive an answer from stdin.
# It returns $default_answer if no answer has be received from stdin.
#
# Globals:
#   None
# Arguments:
#   question ($1)       : The question to ask.
#   default_answer ($2) : Possible values: 'Y', 'y', 'N', 'n' (default: 'Y')
# Returns:
#   0                   : If user replied with either 'Y' or 'y'.
#   1                   : If user replied with either 'N' or 'n'.
#   WRONG_ANSWER        : If `default_answer` is not one of the possible values.
# Output:
#   Print the question to ask.
#######################################
ask() {
	question="$1"
	default_answer="$2"

	check_not_null "$question"

	if [ -n "$default_answer" ]; then
		case "$default_answer" in
		Y | y | N | n) ;;
		*)
			error "The default answer: $default_answer is wrong."
			return $WRONG_ANSWER
			;;
		esac
	fi

	default="Y"
	[ -z "$default_answer" ] || default=$(printf '%s\n' "$default_answer" | tr '[:lower:]' '[:upper:]')

	other="n"
	[ "$default" = "N" ] && other="y"

	prompt=$(info "$question (${default}/${other})> ")

	res="none"
	while [ "$res" != "Y" ] && [ "$res" != "N" ] && [ "$res" != "" ]; do
		printf '%s' "$prompt"
		read -r res
		res=$(echo "$res" | tr '[:lower:]' '[:upper:]')
	done

	[ "$res" = "" ] && res="$default"

	[ "$res" = "Y" ]
}

insert_quotes_on_spaces() {
	# It inserts quotes between arguments.
	# Useful to preserve quotes on command
	# to be used inside sh -c/bash -c
	whitespace="[:space:]"
	for i in "$@"; do
		# shellcheck disable=2254
		case "$i" in
		$whitespace)
			temp_C="\"$i\""
			;;
		*)
			temp_C="$i"
			;;
		esac

		# Handle edge case when C is empty to avoid adding an extra space
		if [ -z "$C" ]; then
			C="$temp_C"
		else
			C="$C $temp_C"
		fi

	done
	echo "$C"
}

contains_element() {
	for e in "$@"; do [ "$e" = "$1" ] && return 0; done
	return 1
}
