#!/bin/bash

#################################################################################
#                                 buildGMAT.sh                                  #
#                                                                               #
# Ubuntu shell script to build the GMAT applications from source.               #
# It requires a GMAT source from SourceForge and a linux system that has had    #
# gmat_dependencies successfully run on it.                                     #
#                                                                               #
# Change History                                                                #
# 07/20/2020  Harry Goldschmitt  Original code.                                 #
# 07/27/2020  Harry Goldschmitt  Removed cmake and make error checking          #
# 09/17/2020  Harry Goldschmitt  Added sourced GMATUtilities.sh and logging     #
# 10/12/2020  Harry Goldschmitt  Changed logic to match GMAT build instructions #
# 11/13/2020  Harry Goldschmitt  Added build options for all supported cmake    #
#                                build configurations.                          #
# 12/16/2020  Harry Goldschmitt  Added better error handling logic              #
#                                                                               #
###############################################################################*#
###############################################################################*#
###############################################################################*#
#                                                                               #
#  Copyright (C) 2020 Harry Goldschmitt                                         #
#  harry@hgac.com                                                               #
#                                                                               #
#  This program is free software; you can redistribute it and/or modify         #
#  it under the terms of the GNU Lesser General Public License as published by  #
#  the Free Software Foundation; either version 3 of the License, or            #
#  (at your option) any later version.                                          #
#                                                                               #
#  This program is distributed in the hope that it will be useful,              #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of               #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
#  GNU General Lesser Public License for more details.                          #
#                                                                               #
#  You should have received a copy of the GNU General Public License            #
#  along with this program; if not, write to the Free Software                  #
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA    #
#                                                                               #
#################################################################################
#################################################################################

#################################################################################
#                                                                               #
# Script - buildGMAT.sh                                                         #
#                                                                               #
# Purpose: Use cmake and make to build and install GMAT                         #
#                                                                               #
# Parameters:                                                                   #
#    buildGMAT.sh [OPTIONS]                                                     #
#      -r, --release [default] - build release configuration                    #
#      -d, --debug             - build debug configuration                      #
#      -m, --minimum           - build minimum size configuration               #
#          --relwithdebug      - build release with debug info configuration    #
#                                                                               #
# Exits:                                                                        #
#    0 - success                                                                #
#    1 - failure                                                                #
#                                                                               #
#################################################################################

export FULLPATH
FULLPATH=$(readlink -f "$0")
export SCRIPT_DIRECTORY
SCRIPT_DIRECTORY="${FULLPATH%/*}"

[ -r "$SCRIPT_DIRECTORY/GMATUtilities.sh" ] || {
    echo "GMATUtilities.sh not found or readable" >&2;
    exit 1; }

# shellcheck source=./GMATUtilities.sh
source "$SCRIPT_DIRECTORY/GMATUtilities.sh"

GMAT_SRC_DIR="gmat"
GMAT_INSTALL_DIR="$HomeDir/$GMAT_SRC_DIR/GMAT-R2020a-Linux-x64/bin"
GMAT_BUILD_DIR="$HomeDir/$GMAT_SRC_DIR/build"
GMAT_BUILD_DIR_LINUX="$GMAT_BUILD_DIR/linux-cmake"

# Check if required directories exist
[ -d "$HomeDir/$GMAT_SRC_DIR/build" ] || errorExit "$GMAT_BUILD_DIR does not exist"

errorMessage="Unable to cd to $GMAT_BUILD_DIR"
cd "$GMAT_BUILD_DIR" 2>&1 | tee --append "$LOG_FILE_NAME"

declare -i SawConfiguration
SawConfiguration=1

declare BuildConfiguration

#
# Function: usage
#
# Output buildGMAT.sh command and parameters help info.
#
function usage
{
    cat <<EOF
NAME
     buildGMAT.sh -- build GMAT(d) and GMATConsole(d) executables

SYNOPSIS
     buildGMAT.sh [OPTION]

DESCRIPTION
     Build GMAT(d) and GMATConsole(d) executable using supported configurations.

OPTIONS
     -h, --help
          Display this help

     -d, --debug [default]
          Build debug configuration

     -r, --release
          Build release configuration

     -m, --minimum
          Build a minimum size configuration

     --releasewithdebug
          Build a release configuration with debug information included
EOF
    return 0
}

function buildOptions
{
    OPTS=$(getopt --name "$SCRIPT_NAME" --options hrdm --long help,release,debug,minimum,releasewithdebug -- "$@")
    if ! [ $? ];
        then echo "Failed parsing options." >&2
        exit 1
    fi

    eval set -- "$OPTS"

    while true; do
        case $1 in
            -h | --help )
                usage
                exit 0
                ;;
            -r | --release )
                if [[ $SawConfiguration == 0 ]]; then
                    errorExit "Configuration specified more than once" >&2
                else
                    SawConfiguration=0
                    BuildConfiguration="Release"
                fi
                shift
                ;;
            -d | --debug )
                if [[ $SawConfiguration == 0 ]]; then
                    errorExit "Configuration specified more than once" >&2
                else
                    SawConfiguration=0
                    BuildConfiguration="Debug"
                fi
                shift
                ;;
            -m | --minimum )
                if [[ $SawConfiguration == 0 ]]; then
                    errorExit "Configuration specified more than once" >&2
                else
                    SawConfiguration=0
                    BuildConfiguration="MinSizeRel"
                fi
                shift
                ;;
            --releasewithdebug )
                if [[ $SawConfiguration == 0 ]]; then
                    errorExit "Configuration specified more than once" >&2
                else
                    SawConfiguration=0
                    BuildConfiguration="RelWithDebInfo"
                fi
                shift
                ;;
            -- )
                shift
                break
                ;;
            * )
                if [ -z "$1" ]; then
                    break;
                else
                    errorExit "$1 is not a valid option"
                fi
                ;;
        esac
    done

    if ! [ $SawConfiguration  -eq 0 ]; then
        BuildConfiguration="Debug"
    fi
}

buildOptions "$@"

errorMessage="Error creating $GMAT_BUILD_DIR_LINUX directory"
mkdir --parents "$GMAT_BUILD_DIR_LINUX"  2>&1 | tee --append "$LOG_FILE_NAME"

errorMessage="Unable to cd to $GMAT_BUILD_DIR_LINUX"
cd "$GMAT_BUILD_DIR_LINUX" 2>&1 && echo "$(pwd)" | tee --append "$LOG_FILE_NAME"

echo "This may take an hour or more for a full build" | tee --append "$LOG_FILE_NAME"
sleep 10

errorMessage="Error running cmake"
cmake -D CMAKE_BUILD_TYPE="$BuildConfiguration" "../.." 2>&1 | tee --append "$LOG_FILE_NAME"

[ -r Makefile ] || errorExit "$PWD/Makefile not readable, check cmake output"

errorMessage="Error running make"
make 2>&1 | tee --append "$LOG_FILE_NAME"

errorMessage="Error running make install"
make install 2>&1 | tee --append "$LOG_FILE_NAME"

echo "GMAT has been built, executables are in $GMAT_INSTALL_DIR" | tee --append "$LOG_FILE_NAME"
echo "   cd to $GMAT_INSTALL_DIR" | tee --append "$LOG_FILE_NAME"

if [ "$BuildConfiguration" == "Debug" ]; then
    echo "   Enter ./GMATd for the display version" | tee --append "$LOG_FILE_NAME"
    echo "   Enter ./GMATConsoled for the console version" | tee --append "$LOG_FILE_NAME"
else
    echo "   Enter ./GMAT for the display version" | tee --append "$LOG_FILE_NAME"
    echo "   Enter ./GMATConsole for the console version" | tee --append "$LOG_FILE_NAME"
fi

exit 0
