#!/bin/bash

################################################################################
#                            createGMATLaucher.sh                              #
#                                                                              #
# Ubuntu shell script to add a GMATd icon to the Ubuntu desktop on a 18.04 box.#
#                                                                              #
# Change History                                                               #
# 08/02/2020  Harry Goldschmitt  Original code.                                #
# 09/18/2020  Harry Goldschmitt  Added sourced GMATUtilities.sh and logging    #
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

################################################################################
#                                                                              #
# Script - createGMATLaucher.sh                                                #
#                                                                              #
# Purpose: Add a GMATd desktop icon to the desktop so GUI users can launch the #
#          GMATd GUI.                                                          #
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

#
# Function: usage
#
# Output createGMATLauncher.sh command and parameters help info.
#
function usage
{
    cat <<EOF
NAME
     createGMATLauncher.sh -- add a GMATd icon on the user's desktop.

SYNOPSIS
     createGMATLauncher.sh [OPTION]

DESCRIPTION
     Add a GMATd icon on the user's desktop.

OPTIONS
     -h, --help
          Display this help
EOF
    return 0
}

options "$@"

GMAT_VERSION="R2020a"
GMAT_SRC_DIR="$HomeDir/gmat"
GMAT_INSTALL_DIR="$GMAT_SRC_DIR//GMAT-$GMAT_VERSION-Linux-x64"
GMAT_PATH_DIR="$GMAT_INSTALL_DIR/bin"

errorMessage="Unable to change to $HomeDir directory"
# shellcheck disable=SC2164
cd "$HomeDir" 2>&1 | tee --append "$LOG_FILE_NAME"

errorMessage="Unable to create $HomeDir/Desktop directory"
mkdir --parents "$HomeDir/Desktop" 2>&1 | tee --append "$LOG_FILE_NAME"

errorMessage="Unable to change to $HomeDir/Desktop directory"
# shellcheck disable=SC2164
cd "$HomeDir/Desktop" 2>&1 | tee --append "$LOG_FILE_NAME"

if ! [ -x "$HomeDir/Desktop/GMATd.desktop" ]; then

    # Create the desktop file to produce the clickable desktop icon
    exec 9<<EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=$GMAT_PATH_DIR/GMATd
Path=$GMAT_PATH_DIR
Name=GMATd
Comment=GMATd GUI
Icon=$GMAT_INSTALL_DIR/data/graphics/icons/GMATIcon.icns
EOF

    errorMessage="Unable to create $HomeDir/Desktop/GMATd.desktop"
    cat <&9 > "$HomeDir/Desktop/GMATd.desktop" 2>&1 | tee --append "$LOG_FILE_NAME"

    errorMessage="Unable to set $HomeDir/Desktop/GMATd.desktop as executable"
    chmod +x "$HomeDir/Desktop/GMATd.desktop" 2>&1 | tee --append "$LOG_FILE_NAME"

    errorMessage="Error running /vagrant/trustGMATdDesktopIcon.sh"
    "$SCRIPT_DIRECTORY/trustGMATdDesktopIcon.sh" 2>&1 | tee --append "$LOG_FILE_NAME"

    echo "A GMATd icon has been created" | tee --append "$LOG_FILE_NAME"
    echo "Note: when clicking on the icon the FIRST time a warning dialog MAY appear stating that GMATd.desktop has" | tee --append "$LOG_FILE_NAME"
    echo "      not been marked as trusted. If this appears please click on the \"Trust and Launch\" button." | tee --append "$LOG_FILE_NAME"
    echo "      This is a GNOME \"Security Feature\" and should only happen once." | tee --append "$LOG_FILE_NAME"

else
    echo "The GMATd icon has previously been created, exiting." | tee --append "$LOG_FILE_NAME"
fi

exit 0
