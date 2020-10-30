#!/bin/bash

################################################################################
#                            createGMATLaucher.sh                              #
#                                                                              #
# Ubuntu shell script to add a GMAT icon to the Ubuntu desktop on a 18.04 box. #
#                                                                              #
# Change History                                                               #
# 08/02/2020  Harry Goldschmitt  Original code.                                #
# 09/18/2020  Harry Goldschmitt  Added sourced GMATUtilities.sh and logging    #
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
# Purpose: Add a GMAT desktop icon to the desktop so GUI users can launch the  #
#          GMAT GUI.                                                           #
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

GMAT_VERSION="R2020a"
GMAT_SRC_DIR="$HomeDir/gmat"
GMAT_INSTALL_DIR="$GMAT_SRC_DIR//GMAT-$GMAT_VERSION-Linux-x64"
GMAT_PATH_DIR="$GMAT_INSTALL_DIR/bin"

# shellcheck disable=SC2164
cd "$HomeDir" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Unable to change to $HomeDir directory"
fi

mkdir --parents "$HomeDir/Desktop" 2>&1; echo "$?" >"$RCFile" | tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Unable to create $HomeDir/Desktop directory"
fi

# shellcheck disable=SC2164
cd "$HomeDir/Desktop" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Unable to change to $HomeDir/Desktop directory"
fi

if ! [ -x "$HomeDir/Desktop/GMAT.desktop" ]; then

    # Create the desktop file to produce the clickable desktop icon
    exec 9<<EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=$GMAT_PATH_DIR/GMAT
Path=$GMAT_PATH_DIR
Name=GMAT
Comment=GMAT GUI
Icon=$GMAT_INSTALL_DIR/data/graphics/icons/GMATIcon.icns
EOF

    cat <&9 > "$HomeDir/Desktop/GMAT.desktop" 2>&1; echo "$?" >"$RCFile" | tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Unable to create $HomeDir/Desktop/GMAT.desktop"
    fi

    chmod +x "$HomeDir/Desktop/GMAT.desktop" 2>&1; echo "$?" >"$RCFile" | tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Unable to set $HomeDir/Desktop/GMAT.desktop as executable"
    fi

    "$SCRIPT_DIRECTORY/trustGMATDesktopIcon.sh" 2>&1; echo "$?" >"$RCFile" | tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Error running /vagrant/trustGMATDesktopIcon.sh"
    fi

    echo "A GMAT icon has been created" | tee --append "$LOG_FILE_NAME"
    echo "Note: when clicking on the icon the FIRST time a warning dialog MAY appear stating that GMAT.desktop has" | tee --append "$LOG_FILE_NAME"
    echo "      not been marked as trusted. If this appears please click on the \"Trust and Launch\" button." | tee --append "$LOG_FILE_NAME"
    echo "      This is a GNOME \"Security Feature\" and should only happen once." | tee --append "$LOG_FILE_NAME"

else
    echo "The GMAT icon has previously been created, exiting." | tee --append "$LOG_FILE_NAME"
fi

exit 0
