#!/bin/bash

################################################################################
#                            gmat_dependencies.sh                              #
#                                                                              #
# Ubuntu shell script to intall all GMAT build dependencies on an Ubuntu       #
# Vagrant 18.04 base box, i.e. Vagrant's ubuntu/bionic64 box.                  #
#                                                                              #
# NOTE:  This script does not replace the configure.py script provided with    #
#        GMAT, but uses it for its final step.                                 #
#                                                                              #
# Change History                                                               #
# 07/20/2020  Harry Goldschmitt  Original code.                                #
# 08/02/2020  Harry Goldschmitt  Added apt install xattr to fix file           #
#                                extended attributes, if needed.               #
# 09/03/2020  Harry Goldschmitt  Use wget to get needed files, added logging,  #
#                                added common sourced utility file.            #
# 10/14/2020  Harry Goldschmitt  Added Kitware repository so latest version of #
#                                cmake can be installed.                       #
# 11/01/2020  Harry Goldschmitt  Support both Ubuntu 18.04 and Ubuntu 20.04    #
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

################################################################################
#                                                                              #
# Script - gmat_dependencies.sh                                                #
#                                                                              #
# Purpose: Assume an Ubuntu Vagrant base system, configure all GMAT            #
#          dependencies, including a clone of the GMAT source at 2020a level.  #
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
# Output gmat_dependencies.sh command and parameters help info.
#
function usage
{
    cat <<EOF
NAME
     gmat_dependencies.sh -- install all GMAT dependencies

SYNOPSIS
     gmat_dependencies.sh [OPTION]

DESCRIPTION
     Install all GMAT dependencies.

OPTIONS
     -h, --help
          Display this help
EOF
    return 0
}

options "$@"

GMAT_REPOSITORY="git://git.code.sf.net/p/gmat/git"
GMAT_SRC_DIR="gmat"
GMAT_Branch="GMAT-R2020a"

echo "Take a break. This may take an hour or more" | tee --append "$LOG_FILE_NAME"
sleep 10

# Make sure other apt command instances have completed
waitForAPT

errorMessage="Can't cd to $HomeDir"
cd "$HomeDir"

# Add repositories
# Add kisak-mesa only for Ubuntu 18.04, it's supported in 20.04
if [ "$UBUNTU_RELEASE" = "18.04" ]; then
    echo "Adding kisak-mesa repository" | tee --append "$LOG_FILE_NAME"
    errorMessage="Can\'t add kisak repository"
    runUnderSUDO apt-add-repository --yes --update --enable-source ppa:kisak/kisak-mesa
fi

# Add any other required repositories here
# sudo apt-add-repository --update --enable-source --yes ppa:octave/stable 2>&1; echo "$?" >"$RCFile"' | \
#    tee --append  "$LOG_FILE_NAME"
#if [[ $(cat "$RCFile") != 0 ]]; then
#    errorExit "Can\'t add octave repository"
#fi

# Upgrade existing system, if needed - Ignore error exits
echo "Performing apt-get update/apt-get upgrade to update base system to the latest level" | tee --append "$LOG_FILE_NAME"

errorMessage="Error updating apt packages"
runUnderSUDO apt-get --quiet --quiet update
errorMessage="Error upgrading apt packages"
runUnderSUDO apt-get --quiet --quiet upgrade

# Install prerequisite packages
export PACKAGES
PACKAGES="zip \
unzip \
p7zip \
xattr \
wget \
subversion \
git-all \
shellcheck \
mlocate \
apt-transport-https \
build-essential \
libgtk2.0-dev \
libgtk2.0-doc \
devhelp \
libgl1-mesa-dev \
libglu1-mesa-dev \
freeglut3 \
freeglut3-dev \
gfortran \
csh \
libgtk2.0-dev \
libgtk2.0-doc \
mesa-utils \
libdrm-dev \
mesa-common-dev \
python3-dev \
libboost-dev"

case "$UBUNTU_RELEASE" in
    18.04 )
        PACKAGES="$PACKAGES libwxgtk3.0-dev libwxgtk3.0-0v5 bsdtar"
        ;;
    20.04 )
        PACKAGES="$PACKAGES libwxgtk3.0-gtk3-dev libwxgtk3.0-gtk3-0v5 libarchive-tools"
        ;;
    * )
        echo "Unknown release - $UBUNTU_RELEASE" | tee --append "$LOG_FILE_NAME"
        exit 1
        ;;
esac

# Octave packages
# octave \
# liboctave-dev \

echo "Installing prerequisite packages" | tee --append "$LOG_FILE_NAME"

errorMessage="Prerequisite package install failed, exiting"
if ! runAPTGet "$PACKAGES"; then
    echo  "$errorMessage" | tee --append "$LOG_FILE_NAME" >&2
    exit 1
fi

# Commands to install cmake packages from Kitware, see https://apt.kitware.com/
echo "Installing Kitware cmake repository" | tee --append "$LOG_FILE_NAME"

case "$UBUNTU_RELEASE" in
    18.04 )
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo -- tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null

        errorMessage="Can\'t add cmake repository"
        runUnderSUDO apt-add-repository --update 'deb https://apt.kitware.com/ubuntu/ bionic main' | tee --append "$LOG_FILE_NAME"
        ;;
    20.04 )
        errorMessage="Error in pipe getting Kitware cmake repository key"
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo -- tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null

        errorMessage="Can\'t add cmake repository"
        runUnderSUDO apt-add-repository --update 'deb https://apt.kitware.com/ubuntu/ focal main' 2>&1 | tee --append "$LOG_FILE_NAME"
        ;;
    * )
        errorExit "Unknown Ubuntu release - $UBUNTU_RELEASE"
        ;;
esac

# Install Kitware keyring, to keep Kitware's keyring up to date
errorMessage="Can\'t install Kitware keyring"
runAPTGet kitware-archive-keyring

if ! runUnderSUDO rm --force /etc/apt/trusted.gpg.d/kitware.gpg; then
    errorExit "Can\'t remove existing Kitware gpg key"
fi

echo "Installing cmake" | tee --append "$LOG_FILE_NAME"
errorMessage="Failed to install cmake packages, exiting"
runAPTGet cmake cmake-qt-gui cmake-curses-gui

echo "Installing Ubuntu desktop - over 900 packages" | tee --append "$LOG_FILE_NAME"
errorMessage="Failed to install Ubuntu desktop, exiting"
runAPTGet ubuntu-desktop

errorMessage="Unable to cd to $HomeDir"
cd "$HomeDir"

# Clone GMAT build to the R2020a revision as of 09/14/2020
echo "Cloning GMAT git at $GMAT_Branch" | tee --append "$LOG_FILE_NAME"
# Delete the gmat directory
errorMessage="Error deleting $HomeDir/$GMAT_SRC_DIR directory"
rm --recursive --force "$GMAT_SRC_DIR" 2>&1 | tee --append "$LOG_FILE_NAME"

# Create the gmat directory
errorMessage="Error creating $HomeDir/$GMAT_SRC_DIR directory"
mkdir --parents "$HomeDir/$GMAT_SRC_DIR"

# Clone the current GMAT repository branch
errorMessage="Error cloning $GMAT_REPOSITORY"
git clone --depth 1 --branch $GMAT_Branch "$GMAT_REPOSITORY" "$GMAT_SRC_DIR" 2>&1 | tee --append "$LOG_FILE_NAME"

errorMessage="Could not cd to $HomeDir/$GMAT_SRC_DIR/depends/"
cd "$HomeDir/$GMAT_SRC_DIR/depends" 2>&1 | tee --append "$LOG_FILE_NAME"

echo "Running GMAT configure.py" | tee --append "$LOG_FILE_NAME"
errorMessage="configure.py failed, check its $GMAT_SRC_DIR/depends/logs"
bash -c "/usr/bin/python3 $HomeDir/$GMAT_SRC_DIR/depends/configure.py 2>&1" | tee --append "$LOG_FILE_NAME"

echo "GMAT dependency creation complete" | tee --append "$LOG_FILE_NAME"

runUnderSUDO shutdown --reboot "+1" "Restarting to enable Ubuntu desktop"

exit 0
