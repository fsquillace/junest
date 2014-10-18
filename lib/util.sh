#!/usr/bin/env bash
#
# This file is part of JuJu: The portable GNU/Linux distribution
#
# Copyright (c) 2012-2014 Filippo Squillace <feel.squally@gmail.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Library General Public License as published
# by the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

echoerr() { echo "$@" 1>&2; }
function die(){
# $@: msg (mandatory) - str: Message to print
    error $@
    exit 1
}
function error(){
# $@: msg (mandatory) - str: Message to print
    echoerr -e "\033[1;31m$@\033[0m"
}
function warn(){
# $@: msg (mandatory) - str: Message to print
    echoerr -e "\033[1;33m$@\033[0m"
}
function info(){
# $@: msg (mandatory) - str: Message to print
    echo -e "\033[1;37m$@\033[0m"
}
