################################################################################
#                               GMATUtilities.sh                               #
#                                                                              #
# Ubuntu shell sourced file containing utility functions used by the           #
# GMAT 6-DOF-Simulator installation scripts.                                   #
#                                                                              #
# Change History                                                               #
# 09/16/2020  Harry Goldschmitt  Original code.                                #
#                                                                              #
#                                                                              #
################################################################################
################################################################################
################################################################################
#                                                                              #
#  Copyright (C) 2020 Harry Goldschmitt                                        #
#  harry@hgac.com                                                              #
#                                                                              #
#  This program is free software; you can redistribute it and/or modify        #
#  it under the terms of the GNU Lesser General Public License as published by #
#  the Free Software Foundation; either version 3 of the License, or           #
#  (at your option) any later version.                                         #
#                                                                              #
#  This program is distributed in the hope that it will be useful,             #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#  GNU General Lesser Public License for more details.                         #
#                                                                              #
#  You should have received a copy of the GNU General Public License           #
#  along with this program; if not, write to the Free Software                 #
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA   #
#                                                                              #
################################################################################

ExcludePath=${0/\/*\/}
ScriptName=${ExcludePath/.*/}

# Make sure this file has been sourced
if [ "$ScriptName" == "GMATUtilities" ]; then
    echo "$ScriptName.sh must be sourced, it is not executable" >&2
    exit 1
fi

################################################################################
#                                                                              #
# Common variables useful in all installation scripts                          #
#                                                                              #
################################################################################

SCRIPT_DIRECTORY="/vagrant"
[ -d $SCRIPT_DIRECTORY ] || \
    SCRIPT_DIRECTORY="$HOME"

export HomeDir
HomeDir="$HOME"

LOG_DIR_NAME="$HomeDir/GMAT_Install_Script_Logs"
LOG_FILE_NAME="$LOG_DIR_NAME/$ScriptName-$(date +%Y%m%d-%H%M%S).log"

#
# Function: createLogFile
#
# Parameters:
#    None
#
# Description: Create a log file for running script.
#
function createLogFile
{
    # Set up log directory and log
    mkdir --parents "$LOG_DIR_NAME" || {
        echo "Unable to create log directory $LOG_DIR_NAME" >&2;
        exit 1; }

    touch "$LOG_FILE_NAME" || {
        echo "Unable to create log file $LOG_FILE_NAME" >&2;
        exit 1; }
}

createLogFile

export RCFile
RCFile=""

#
# Function: finish
#
# trap finish EXIT
#
# Description: trap function to delete RCFile, if present
#
function finish
{
    if [[ -n "$RCFile" ]]; then
        rm --force "$RCFile"
    fi
}

# Setup EXIT trap
trap finish EXIT

RCFile=$(mktemp) || {
    echo "mktemp failure" >&2;
    exit 1; }

touch "$RCFile" || {
    echo "Could not create $RCFile" >&2;
    exit 1; }

#
# Function: errorExit
#
# errorExit message
#
# Parameter:
#    message - error message to be issued
#
# Description: Issue the message to stderr and exit 1.
#
function errorExit
{
    echo "$@" | tee --append "$LOG_FILE_NAME" >&2
    exit 1
}

#
# Function: waitForAPT
#
# waitForAPT
#
# Description: Loop until all processes using the apt locks complete
#
function waitForAPT
{
    while pgrep apt >/dev/null; do
        echo "Another apt instance is running, waiting for 3 seconds for apt to complete" | tee --append "$LOG_FILE_NAME"
        sleep 3
    done
    return 0
}

waitForAPT
