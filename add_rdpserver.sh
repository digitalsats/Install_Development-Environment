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

SCRIPT_DIRECTORY="/vagrant"
[ -d $SCRIPT_DIRECTORY ] || \
    SCRIPT_DIRECTORY="$HOME"

[ -r "$SCRIPT_DIRECTORY/GMATUtilities.sh" ] || {
    echo "GMATUtilities.sh not found or readable" >&2;
    exit 1; }

# shellcheck source=./GMATUtilities.sh
source "$SCRIPT_DIRECTORY/GMATUtilities.sh"

XRDP_INSTALLER_VERSION="1.2"
XRDP_INSTALLER_URL="https://c-nergy.be/downloads/xRDP/xrdp-installer-$XRDP_INSTALLER_VERSION.zip"

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

wget --continue "$XRDP_INSTALLER_URL" --output-document xrdp-installer-"$XRDP_INSTALLER_VERSION.zip" --append-output "$LOG_FILE_NAME"; echo "$?" >"$RCFile"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error downloading xrdp-installer-$XRDP_INSTALLER_VERSION.zip"
fi

INSTALLER_ZIP=$(echo xrdp-installer-*.zip)
if [ "$INSTALLER_ZIP" = "xrdp-installer-*.zip" ]; then
    errorExit "Could not find xrdp-installer zip file"
fi

unzip -o "$INSTALLER_ZIP" 2>&1; echo "$?" >"$RCFile" | \
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error unzipping $INSTALLER_ZIP"
fi

INSTALLER=$(echo xrdp-installer-*.sh)
if [[ "$INSTALLER" == "xrdp-installer-*.sh" ]]; then
    errorExit "Could not find xrdp installer script"
fi

chmod +x "$INSTALLER" 2>&1; echo "$?" >"$RCFile" | \
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Could not set executable mode on $INSTALLER"
fi

# Attempt to remove xrdp server, if installed, do not check return code
bash -c "$HomeDir/$INSTALLER -r" 2>&1 | tee --append "$LOG_FILE_NAME"

sudo  --preserve-env /bin/bash -c 'systemctl daemon-reload 2>&1; echo "$?" >"$RCFile"' | \
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error with systemctl daemon-reload"
fi

bash -c "$HomeDir/$INSTALLER -c" 2>&1; echo "$?" >"$RCFile" |
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error installing xrdp"
fi

service xrdp status >/dev/null || errorExit "xrdp server has not started"

typeset -i defaultPort=33389
typeset -i rdpPort=$defaultPort

if [ -f "/vagrant/Vagrantfile" ]; then
    if grep -q rdpPort "/vagrant/Vagrantfile"; then
        rdpPort=$(grep -vE '^ *#' "/vagrant/Vagrantfile" | grep -v '^ *$' | grep -E 'rdp' | sed -e 's/^.*host: //' | sed -e 's/,.*//'| head -1) || \
            errorExit "Could not parse Vagrantfile"
    fi
fi

"$SCRIPT_DIRECTORY/createGMATLauncher.sh" || errorExit "Error running createGMATLauncher.sh"

echo "RDP has been added to this vagrant box. It can be accessed from an RDP client by issuing 'vagrant rdp'" | tee --append "$LOG_FILE_NAME"
echo "or by connecting a host rdp client to localhost:$rdpPort." | tee --append "$LOG_FILE_NAME"
echo "Log in as user vagrant, password vagrant." | tee --append "$LOG_FILE_NAME"

exit 0
