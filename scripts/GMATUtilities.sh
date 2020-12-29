################################################################################
#                               GMATUtilities.sh                               #
#                                                                              #
# Ubuntu shell sourced file containing utility functions used by the           #
# GMAT 6-DOF-Simulator installation scripts.                                   #
#                                                                              #
# Change History                                                               #
# 09/16/2020  Harry Goldschmitt  Original code.                                #
# 12/16/2020  Harry Goldschmitt  Added better error handling logic             #
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

FULL_SCRIPT_NAME="${FULLPATH##*/}"
export SCRIPT_NAME
SCRIPT_NAME="${FULL_SCRIPT_NAME%%.*}"

# Make sure this file has been sourced
if [ "$SCRIPT_NAME" == "GMATUtilities" ]; then
    echo "$SCRIPT_NAME.sh must be sourced, it is not executable" >&2
    exit 1
fi

################################################################################
#                                                                              #
# Common variables useful in all installation scripts                          #
#                                                                              #
################################################################################

################################################################################
#                                                                              #
# Set up to handle errors and output diagnostics                               #
#                                                                              #
################################################################################

export errorMessage
errorMessage=""

## Outputs Front-Mater formatted failures for functions not returning 0
## Use the following line after sourcing this file to set failure trap
##    trap 'failure "LINENO" "BASH_LINENO" "${BASH_COMMAND}" "${?}"' ERR
failure(){
    local -n _lineno="${1:-LINENO}"
    local -n _bash_lineno="${2:-BASH_LINENO}"
    local _last_command="${3:-${BASH_COMMAND}}"
    local _code="${4:-0}"

    if [ -n "$errorMessage" ]; then
        echo "$errorMessage" | tee --append "$LOG_FILE_NAME" >&2
    fi

    ## Workaround for read EOF combo tripping traps
    if ! ((_code)); then
        return "${_code}"
    fi

    local _last_command_height
    _last_command_height="$(wc -l <<<"${_last_command}")"

    local -a _output_array=()
    _output_array+=(
        '---'
        "lines_history: [${_lineno} ${_bash_lineno[*]}]"
        "function_trace: [${FUNCNAME[*]}]"
        "exit_code: ${_code}"
    )

    if [[ "${#BASH_SOURCE[@]}" -gt '1' ]]; then
        _output_array+=('source_trace:')
        for _item in "${BASH_SOURCE[@]}"; do
            _output_array+=("  - ${_item}")
        done
    else
        _output_array+=("source_trace: [${BASH_SOURCE[*]}]")
    fi

    if [[ "${_last_command_height}" -gt '1' ]]; then
        _output_array+=(
            'last_command: ->'
            "${_last_command}"
        )
    else
        _output_array+=("last_command: ${_last_command}")
    fi

    _output_array+=('---')
    printf '%s\n' "${_output_array[@]}" >&2
    exit "${_code}"
}



#
# Function: SetERRTrap
#
# Parameters:
#    None
#
# Description: Set ERR trap
#
function SetERRTrap
{

    # Set up to: inherit "trap ERR" in function calls, exit immediately on pipeline
    # errors, consider unititialized variables an error, turn on pipefail so pipes
    # exit immediately on the first error return and finally provide functrace so
    # the failure function can output a traceback.
    set -Eeu -o pipefail -o functrace

    trap 'failure "LINENO" "BASH_LINENO" "${BASH_COMMAND}" "${?}"' ERR
}

SetERRTrap

#
# Function: ClearERRTrap
#
# Parameters:
#    None
#
# Description: Clear ERR trap for expected errors
#
function ClearERRTrap
{

    # Turn off settings used by the failure function
    set +Eeu +o pipefail +o functrace

    trap '' ERR
}

export HomeDir
HomeDir="$HOME"
export LOG_DIR_NAME
LOG_DIR_NAME="$HomeDir/GMAT_Install_Script_Logs"
LOG_FILE_NAME="$LOG_DIR_NAME/$SCRIPT_NAME-$(date +%Y%m%d-%H%M%S).log"

function options
{
    OPTS=$(getopt --name "$SCRIPT_NAME" --options h --long help -- "$@")
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
}

declare -i RC
export RC

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
    errorMessage="Unable to create log directory $LOG_DIR_NAME"
    mkdir --parents "$LOG_DIR_NAME"

    errorMessage="Unable to create log file $LOG_FILE_NAME"
    touch "$LOG_FILE_NAME"
}

createLogFile

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
    errorMessage="$*"
    echo "$errorMessage" | tee --append "$LOG_FILE_NAME" >&2
    # Deliberately force an error
    false
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

export APT_PACKAGES

#
# Function: runUnderSUDO
#
# runUnderSUDO command and parameters
#
function runUnderSUDO
{
    if [ $# -eq 0 ]; then
        errorExit "runUnderSUDO requires at least one parameter"
    fi

    local sudo_result=0

    # shellcheck disable=SC2068
    sudo --preserve-env -- "$@"  2>&1 | tee --append "$LOG_FILE_NAME"

    return "$sudo_result"
}

#
# Functioun: runAPTGet
#
# runAPTGet "package list"
#
# Description: Run apt-get under sudo
#
function runAPTGet
{
    if [ $# -eq 0 ]; then
        errorExit "runAPTGet requires at least one parameter"
    fi

    local APT_PACKAGES="$*"
    local apt_result=0

    # shellcheck disable=SC2086
    runUnderSUDO /usr/bin/apt-get --quiet --quiet install $APT_PACKAGES
    apt_result=$?

    if [[ $apt_result != 0 ]]; then
        errorExit "Error running apt-get"
    fi

    return "$apt_result"
}

export UBUNTU_RELEASE

#
# Function: getUbuntuRelease
#
# Parameters:
#    None
#
# Purpose: Set up UBUNTU_RELEASE environment variable.
#
# Description: Verify this is Ubuntu 18.04 or Ubuntu 20.04 and set up
#              UBUNTU_RELEASE environment variable.
#
function getUbuntuRelease
{
    # Make sure the lsb_release is installed.
    if [ -z "$(command -v lsb_release)" ]; then
        if ! runAPTGet lsb_release; then
            errorExit "Error running apt-get lsb_release"
        fi
    fi

    # Check this system's distribution
    if [ "$( lsb_release --id | cut --fields 2 )" != "Ubuntu" ]; then
        errorExit "This script can only execute on an Ubuntu system, exiting"
    fi

    # Check this system's release
    UBUNTU_RELEASE="$( lsb_release --release | cut --fields 2 )"

    if ! [[ "$UBUNTU_RELEASE" = "18.04" ]] && ! [[ $UBUNTU_RELEASE = "20.04" ]]; then
        errorExit "This script can only execute on an Ubuntu 18.04 or Ubuntu 20.04 system, exiting"
    fi

    return 0
}

getUbuntuRelease
