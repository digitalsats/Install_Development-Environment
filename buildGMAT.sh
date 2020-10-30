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
# Exits:                                                                        #
#    0 - success                                                                #
#    1 - failure                                                                #
#                                                                               #
#################################################################################

SCRIPT_DIRECTORY="/vagrant"
[ -d $SCRIPT_DIRECTORY ] || \
    SCRIPT_DIRECTORY="$HOME"

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
cd "$GMAT_BUILD_DIR" >>"$LOG_FILE_NAME" 2>&1 || \
    errorExit "Unable to cd to $GMAT_BUILD_DIR"

mkdir --parents "$GMAT_BUILD_DIR_LINUX"  2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error creating $GMAT_BUILD_DIR_LINUX directory"
fi

cd "$GMAT_BUILD_DIR_LINUX" >>"$LOG_FILE_NAME" 2>&1 || \
    errorExit "Unable to cd to $GMAT_BUILD_DIR_LINUX"

echo "This may take an hour or more for a full build" | tee --append "$LOG_FILE_NAME"
sleep 10

cmake ../.. 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error running cmake"
fi

[ -r Makefile ] || errorExit "$PWD/Makefile not readable, check cmake output"

make 2>&1 ; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error running make"
fi

make install 2>&1 ; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error running make install"
fi

echo "GMAT has been built, executables are in $GMAT_INSTALL_DIR" | tee --append "$LOG_FILE_NAME"
echo "   cd to $GMAT_INSTALL_DIR" | tee --append "$LOG_FILE_NAME"
echo "   Enter ./GMAT for the display version" | tee --append "$LOG_FILE_NAME"
echo "   Enter ./GMATConsole for the console version" | tee --append "$LOG_FILE_NAME"

exit 0
