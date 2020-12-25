#!/bin/bash

################################################################################
#                               add_rdpserver.sh                               #
#                                                                              #
# Ubuntu shell script to install an RDP server on a Vagrant Ubuntu 18.04 box.  #
# It utilizes the latest xrdp-installer-nn.sh script file from                 #
# http://www.c-nergy.be                                                        #
#                                                                              #
# Change History                                                               #
# 07/20/2020  Harry Goldschmitt  Original code.                                #
# 08/02/2020  Harry Goldschmitt  Made script restartible                       #
# 08/04/2020  Harry Goldschmitt  Added -c to xrdp install script for Ubuntu    #
#                                18.04 bug fixes                               #
# 09/17/2020  Harry Goldschmitt  Added sourced GMATUtilities.sh and logging    #
# 12/06/2020  Harry Goldschmitt  Added latest package and security requirments.#
# 12/16/2020  Harry Goldschmitt  Added better error handling logic             #
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
#                                                                              #
# Script - add_rdpserver.sh                                                    #
#                                                                              #
# Purpose: Add a rdp server environment to Ubuntu 18.04                        #
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

XRDP_INSTALLER_VERSION="1.2.1"
XRDP_INSTALLER_URL="https://c-nergy.be/downloads/xrdp-installer-$XRDP_INSTALLER_VERSION.zip"

#
# Function: usage
#
# Output add_rdpserver.sh command and parameters help info.
#
function usage
{
    cat <<EOF
NAME
     add_rdpserver.sh -- add an xrdp server to the system.

SYNOPSIS
     add_rdpserver.sh [OPTION]

DESCRIPTION
     Add an RDP server.

OPTIONS
     -h, --help
          Display this help
EOF
    return 0
}

options "$@"

# Script: add_rdpserver.sh
#
# Purpose: Add an rdpserver to a GMAT build Ubuntu box
#
# Parameters: None
#
# Return codes:
#   0 - success
#   1 - failure
#
cd "$HomeDir" || errorExit "Could not cd to $HomeDir directory"

errorMessage="Error downloading xrdp-installer-$XRDP_INSTALLER_VERSION.zip"
wget --continue "$XRDP_INSTALLER_URL" --output-document xrdp-installer-"$XRDP_INSTALLER_VERSION.zip" --append-output "$LOG_FILE_NAME"

case "$UBUNTU_RELEASE" in
    18.04 )
        scriptParameter="-c"
        ;;
    20.04 )
        scriptParameter=""
        ;;
    * )
        errorExit "Unknown release - $UBUNTU_RELEASE"
        ;;
esac

# We need to install more packages, but first run apt-get update
errorMessage="Error during apt-get update"
runUnderSUDO apt-get --quiet --quiet update
errorMessage="Error upgrading apt packages"
runUnderSUDO apt-get --quiet --quiet upgrade

INSTALLER_ZIP=$(echo xrdp-installer-*.zip)
if [ "$INSTALLER_ZIP" = "xrdp-installer-*.zip" ]; then
    errorExit "Could not find xrdp-installer zip file"
fi

errorMessage="Error unzipping $INSTALLER_ZIP"
unzip -o "$INSTALLER_ZIP" 2>&1 | tee --append  "$LOG_FILE_NAME"

INSTALLER=$(echo xrdp-installer-*.sh)
if [[ "$INSTALLER" == "xrdp-installer-*.sh" ]]; then
    errorExit "Could not find xrdp installer script"
fi

errorMessage="Could not set executable mode on $INSTALLER"
chmod +x "$INSTALLER" 2>&1 | tee --append  "$LOG_FILE_NAME"

# Attempt to remove xrdp server, if installed, do not check return code
bash -c "$HomeDir/$INSTALLER -r" 2>&1 | tee --append "$LOG_FILE_NAME"

errorMessage="Error with systemctl daemon-reload"
runUnderSUDO systemctl daemon-reload

errorMessage="Error installing xrdp"
bash -c "$HomeDir/$INSTALLER $scriptParameter" 2>&1 | tee --append  "$LOG_FILE_NAME"

errorMessage="xrdp server has not started"
case "$UBUNTU_RELEASE" in
    18.04 )
        service xrdp status >/dev/null
        ;;
    20.04 )
        systemctl status xrdp >/dev/null
        ;;
    * )
        errorExit "Unknown release - $UBUNTU_RELEASE"
        ;;
esac

errorMessage="Error enabling firewall RDP port"
runUnderSUDO ufw allow 3389

typeset -i defaultPort=33389
typeset -i rdpPort=$defaultPort

if [ -f "/vagrant/Vagrantfile" ]; then
    if grep -q rdp "/vagrant/Vagrantfile"; then
        rdpPort=$(grep -vE '^ *#' "/vagrant/Vagrantfile" | grep -v '^ *$' | grep -E 'rdp' | sed -e 's/^.*host: //' | sed -e 's/,.*//'| head -1) || \
            errorExit "Could not parse Vagrantfile"
    fi
fi

errorMessage="Error running createGMATLauncher.sh"
"$SCRIPT_DIRECTORY/createGMATLauncher.sh"

errorMessage="Error deleting xrdp-installer files"
rm "$HomeDir"/xrdp-installer* 2>&1 | tee --append  "$LOG_FILE_NAME"

echo "RDP has been added to this vagrant box. It can be accessed from an RDP client by issuing 'vagrant rdp'" | tee --append "$LOG_FILE_NAME"
echo "or by connecting a host rdp client to localhost:$rdpPort." | tee --append "$LOG_FILE_NAME"
echo "Log in as user vagrant, password vagrant." | tee --append "$LOG_FILE_NAME"

exit 0
