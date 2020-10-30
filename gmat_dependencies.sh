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

SCRIPT_DIRECTORY="/vagrant"
[ -d $SCRIPT_DIRECTORY ] || \
    SCRIPT_DIRECTORY="$HOME"

[ -r "$SCRIPT_DIRECTORY/GMATUtilities.sh" ] || {
    echo "GMATUtilities.sh not found or readable" >&2;
    exit 1; }

# shellcheck source=./GMATUtilities.sh
source "$SCRIPT_DIRECTORY/GMATUtilities.sh"

GMAT_VERSION="R2020a"
GMAT_REPOSITORY="https://git.code.sf.net/p/gmat/git"
GMAT_SRC_DIR="gmat"
GMAT_2020a_HEAD_SHA1="d17522c9b3aba39cf723f225690af344712829a3"

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
        echo "Another apt instance is running, waiting for 3 seconds" | tee --append "$LOG_FILE_NAME"
        sleep 3
    done
    return 0
}

echo "Take a break. This may take an hour or more" | tee --append "$LOG_FILE_NAME"
sleep 10

# Make sure other apt command instances have completed
waitForAPT

cd "$HomeDir" || errorExit "Can't cd to $HomeDir"

# Note: In order to retain the sudo command's return codes, all the following sudo commands save their return codes
# in $RCFile, before the sudo command exits. This return code is checked after the sudo exits, and the proper steps
# are taken.

# Add repositories
echo "Adding kisak-mesa repository" | tee --append "$LOG_FILE_NAME"
sudo --preserve-env /bin/bash -c 'apt-add-repository --yes --update --enable-source ppa:kisak/kisak-mesa 2>&1; echo "$?" >"$RCFile"' | \
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Can\'t add kisak repository"
fi

# Add any other required repositories here
# sudo apt-add-repository --update --enable-source --yes ppa:octave/stable 2>&1; echo "$?" >"$RCFile"' | \
#    tee --append  "$LOG_FILE_NAME"
#if [[ $(cat "$RCFile") != 0 ]]; then
#    errorExit "Can\'t add octave repository"
#fi

# Upgrade existing system, if needed - Ignore error exits
echo "Performing apt-get update/apt-get upgrade to update base system to the latest level" | tee --append "$LOG_FILE_NAME"
sudo /bin/bash -c 'apt-get --quiet --quiet update --yes 2>&1' | tee --append "$LOG_FILE_NAME"
sudo /bin/bash -c 'apt-get --quiet --quiet upgrade --yes 2>&1' | tee --append "$LOG_FILE_NAME"

# Install prerequisite packages
export PACKAGES
PACKAGES="zip \
unzip \
p7zip \
xattr \
wget \
subversion \
git \
shellcheck \
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
libwxgtk3.0-0v5 \
csh \
libgtk2.0-dev \
libgtk2.0-doc \
libwxgtk3.0-gtk3-dev \
mesa-utils \
libdrm-dev \
mesa-common-dev \
python3-dev \
libboost-dev"

# Octave packages
# octave \
# liboctave-dev \

echo "Installing prerequisite packages" | tee --append "$LOG_FILE_NAME"
sudo --preserve-env /bin/bash -c 'apt-get --quiet --quiet install --yes $PACKAGES 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Prerequisite package install failed, exiting"
fi

# Commands to install cmake packages from Kitware, see https://apt.kitware.com/
echo "Installing Kitware cmake repository" | tee --append "$LOG_FILE_NAME"
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
sudo --preserve-env /bin/bash -c 'apt-add-repository --yes --update --enable-source '\''deb https://apt.kitware.com/ubuntu/ bionic main'\'' 2>&1; echo "$?" >"$RCFile"' | \
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Can\'t add cmake repository"
fi

# Install Kitware keyring, to keep Kitware's keyring up to date
sudo --preserve-env /bin/bash -c 'apt-get --quiet --quiet install --yes kitware-archive-keyring 2>&1; echo "$?" >"$RCFile"' | \
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Can\'t install Kitware keyring"
fi

sudo --preserve-env /bin/bash -c 'rm --force /etc/apt/trusted.gpg.d/kitware.gpg 2>&1; echo "$?" >"$RCFile"' | \
    tee --append  "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Can\'t remove existing Kitware gpg key"
fi

export CMAKE_PACKAGES
CMAKE_PACKAGES="cmake cmake-qt-gui cmake-curses-gui"
echo "Installing cmake" | tee --append "$LOG_FILE_NAME"
sudo --preserve-env /bin/bash -c 'apt-get --quiet --quiet install --yes $CMAKE_PACKAGES 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Failed to install cmake packages, exiting"
fi

echo "Installing Ubuntu desktop - over 900 packages" | tee --append "$LOG_FILE_NAME"
sudo --preserve-env /bin/bash -c 'apt-get --quiet --quiet install --yes ubuntu-desktop 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Ubuntu desktop install failed, exiting"
fi

cd "$HomeDir" >>"$LOG_FILE_NAME" 2>&1 || \
    errorExit "Unable to cd to $HomeDir"

# Clone GMAT build to the R2020a revision as of 09/14/2020
echo "Cloning GMAT git at $GMAT_VERSION" | tee --append "$LOG_FILE_NAME"
# Delete the gmat directory
rm --recursive --force "$GMAT_SRC_DIR" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error deleting $HomeDir/$GMAT_SRC_DIR directory"
fi

# Create the gmat directory
mkdir --parents "$HomeDir/$GMAT_SRC_DIR" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error creating $HomeDir/$GMAT_SRC_DIR directory"
fi

# Clone the current GMAT repository
# For some unknown reason cloning the Source Forge GMAT git repository does not provide the correct contents of the gmat/depends directory,
# so force the repository to a specific SHA1 release.
git clone "$GMAT_REPOSITORY" "$GMAT_SRC_DIR" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error gmat/git"
fi

# shellcheck disable=SC2164
cd "$HomeDir/$GMAT_SRC_DIR" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Could not cd to $HomeDir/$GMAT_SRC_DIR"
fi

git checkout "$GMAT_2020a_HEAD_SHA1" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Could not checkout required SHA1"
fi

git reset --hard 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Could not reset repository"
fi

# shellcheck disable=SC2164
cd "$HomeDir/$GMAT_SRC_DIR/depends" 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Could not cd to $HomeDir/$GMAT_SRC_DIR/depends/"
fi

echo "Running GMAT configure.py" | tee --append "$LOG_FILE_NAME"
python3 ./configure.py 2>&1; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "configure.py failed, check its $GMAT_SRC_DIR/depends/logs"
fi

echo "GMAT dependency creation complete" | tee --append "$LOG_FILE_NAME"

sudo --preserve-env /bin/bash -c 'shutdown --reboot "+1" "Restarting to enable Ubuntu desktop" 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error restarting system"
fi

exit 0
