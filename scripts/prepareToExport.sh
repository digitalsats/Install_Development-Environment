#!/bin/bash

################################################################################L
#                            prepareToExport.sh                                #
#                                                                              #
# Ubuntu shell script to prepare a virtual machine for export either as a .OVA #
# file or as a vagrant .box file.                                              #
#                                                                              #
# The actual export must be done via the vagrant box repackage command or      #
# with the provider's export facility.                                         #
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
################################################################################

################################################################################
#                                                                              #
# Script - prepareToExport.sh                                                  #
#                                                                              #
# Purpose: Assume an Ubuntu Vagrant base system, clean up everything possible  #
#          and add the public vagrant user key so that vagrant can bring up    #
#          the new box.                                                        #
#                                                                              #
# Exits:                                                                       #
#    0 - success                                                               #
#    1 - failure                                                               #
#                                                                              #
################################################################################

export FULLPATH
FULLPATH=$(readlink -f "$0")
export SCRIPT_DIRECTORY
SCRIPT_DIRECTORY="${FULLPATH%/*}"

[ -r "$SCRIPT_DIRECTORY/GMATUtilities.sh" ] || {
    echo "GMATUtilities.sh not found or readable" >&2;
    exit 1; }

# shellcheck source=./GMATUtilities.sh
source "$SCRIPT_DIRECTORY/GMATUtilities.sh"

function waitForAPT
{
    while pgrep apt >/dev/null; do
        echo "Another apt instance is running, waiting for 3 seconds" | tee --append "$LOG_FILE_NAME"
        sleep 3
    done
    return 0
}

#
# Function: usage
#
# Output prepareToExport.sh command and parameters help info.
#
function usage
{
    cat <<EOF
NAME
     prepareToExport.sh -- Clear out a system, before exporting to a
     .OVI file and/or Vagrant box

SYNOPSIS
     prepareToExport.sh [OPTION]

DESCRIPTION
     Add an RDP server.

OPTIONS
     -h, --help
          Display this help
EOF
    return 0
}

options "$@"

# Make sure other apt command instances have completed
waitForAPT

cd "$HomeDir" || errorExit "Can't cd to $HomeDir"

preventLoopFile="/tmp/bootingToUpgradeKernel"

# Upgrade existing system, if needed - Ignore error exits
echo "Performing apt-get update/apt-get upgrade to update base system to the latest level" | tee --append "$LOG_FILE_NAME"

runUnderSUDO apt-get --quiet --quiet update
runUnderSUDO apt-get --quiet --quiet upgrade

# See if more than 1 kernel is present
declare -i NumberOfKernels
NumberOfKernels=$(dpkg --list | grep -v virtual | grep linux-image | sort -k 3 | awk '{print $3}' | wc -l)
currentKernel="$(uname --kernel-release | cut --delimiter '-' --fields 1,2)"

latestKernelFull="$(dpkg --list | grep -v virtual | grep linux-image | sort -k 3 | tail -1 | awk '{print $3}')"
latestKernel="${latestKernelFull%.*}"

if [[ $NumberOfKernels -gt 1 ]]; then
    # Check whether we have to reboot
    if ! [[ "$currentKernel" == "$latestKernel" ]]; then
        if ! [ -e "$preventLoopFile" ]; then

            errorMessage="Error result from touch command"
            touch "$preventLoopFile" 2>&1 | tee --append "$LOG_FILE_NAME"

            runUnderSUDO shutdown --reboot "+1" "Restarting to boot latest kernel, please rerun ${0##*/} after reboot."
        else
            echo "Removing $preventLoopFile" | tee --append "$LOG_FILE_NAME"
            rm --force $preventLoopFile
        fi
    fi
fi

# Get the Vagrant public key and set up SSH to use it
errorMessage="Error getting public key"
wget -c --no-check-certificate https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -O .ssh/authorized_keys 2>&1 | tee  --append "$LOG_FILE_NAME"

errorMessage="Error setting .ssh mode to 700"
chmod 700 .ssh 2>&1 | tee  --append "$LOG_FILE_NAME"

errorMessage="Error setting .ssh/authorized_keys mode to 600"
chmod 600 .ssh/authorized_keys 2>&1 | tee  --append "$LOG_FILE_NAME"

errorMessage="Error setting .ssh owner to vagrant:vagrant"
chown -R vagrant:vagrant .ssh 2>&1 | tee  --append "$LOG_FILE_NAME"

# Clean up old kernels with linux-purge

# Download linux-purge install shell script
errorMessage="Error downloading /tmp/install-linux-purge.sh"
wget -c --no-check-certificate -N https://git.launchpad.net/linux-purge/plain/install-linux-purge.sh -O /tmp/install-linux-purge.sh 2>&1 | tee  --append "$LOG_FILE_NAME"

# Set the install script to executable
errorMessage="Error setting /tmp/install-linux-purge.sh mode to executable"
chmod +x /tmp/install-linux-purge.sh 2>&1 | tee  --append "$LOG_FILE_NAME"

# Install linux-purge and delete the install script
errorMessage="Error installing linux-purge"
runUnderSUDO /tmp/install-linux-purge.sh

errorMessage="Error deleting /tmp/install-linux-purge.sh"
rm /tmp/install-linux-purge.sh

# Delete all old kernels
errorMessage="linux-purge failed"
runUnderSUDO linux-purge -k 0 -y

echo "Clearing apt cache" | tee  --append "$LOG_FILE_NAME"
errorMessage="Error clearing apt cache"
runUnderSUDO apt-get clean

echo "Removing old log files" | tee  --append "$LOG_FILE_NAME"
errorMessage="Removing old log files"
find "$LOG_DIR_NAME" -type f -not -wholename "$LOG_FILE_NAME" -delete 2>&1 | tee  --append "$LOG_FILE_NAME"

echo "Zeroing free disk space - this will take a while" | tee  --append "$LOG_FILE_NAME"
# dd will end with an error, so turn off immediate error processing for it.
ClearERRTrap
set +e
runUnderSUDO dd if=/dev/zero of=/EMPTY bs=5M
set -e
SetERRTrap

errorMessage="Error deleting zero file"
runUnderSUDO rm /EMPTY # The dd command, above, will fail, but remove the empty file

errorMessage="Error powering off system"
runUnderSUDO shutdown --poweroff "+1" "Shutting down system, please create the Vagrant Box and/or the .ova file after shutdown"