#!/usr/bin/env bash

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
function check_not_null() {
    [ -z "$1" ] && { error "Error: null argument $1"; return $NULL_EXCEPTION; }
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
function echoerr() {
    echo "$@" 1>&2;
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
function die() {
    error $@
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
function die_on_status() {
    status=$1
    shift
    error $@
    exit $status
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
function error() {
    echoerr -e "\033[1;31m$@\033[0m"
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
function warn() {
    # $@: msg (mandatory) - str: Message to print
    echoerr -e "\033[1;33m$@\033[0m"
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
function info(){
    echo -e "\033[1;36m$@\033[0m"
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
function ask(){
    local question=$1
    local default_answer=$2
    check_not_null $question

    if [ ! -z "$default_answer" ]
    then
        local answers="Y y N n"
        [[ "$answers" =~ "$default_answer" ]] || { error "The default answer: $default_answer is wrong."; return $WRONG_ANSWER; }
    fi

    local default="Y"
    [ -z "$default_answer" ] || default=$(echo "$default_answer" | tr '[:lower:]' '[:upper:]')

    local other="n"
    [ "$default" == "N" ] && other="y"

    local prompt=$(info "$question (${default}/${other})> ")

    local res="none"
    while [ "$res" != "Y" ] && [ "$res" != "N"  ] && [ "$res" != "" ];
    do
        read -p "$prompt" res
        res=$(echo "$res" | tr '[:lower:]' '[:upper:]')
    done

    [ "$res" == "" ] && res="$default"

    [ "$res" == "Y" ]
}

function check_and_trap() {
    local sigs="${@:2:${#@}}"
    local traps="$(trap -p $sigs)"
    [[ $traps ]] && die "Attempting to overwrite existing $sigs trap: $traps"
    trap $@
}

function check_and_force_trap() {
    local sigs="${@:2:${#@}}"
    local traps="$(trap -p $sigs)"
    [[ $traps ]] && warn "Attempting to overwrite existing $sigs trap: $traps"
    trap $@
}

function insert_quotes_on_spaces(){
# It inserts quotes between arguments.
# Useful to preserve quotes on command
# to be used inside sh -c/bash -c
    C=''
    whitespace="[[:space:]]"
    for i in "$@"
    do
        if [[ $i =~ $whitespace ]]
        then
            C="$C \"$i\""
        else
            C="$C $i"
        fi
    done
    echo $C
}

contains_element () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}
