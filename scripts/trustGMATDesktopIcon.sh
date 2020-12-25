#!/bin/bash

######################################################################################################################
#                              trustGMATDesktop.sh                                                                   #
#                                                                                                                    #
# Ubuntu shell script to set the trust attribute on the GMAT desktop icon.                                           #
# It is based on a script posted by Janos on StackExchange -- AskUbuntu                                              #
# https://askubuntu.com/questions/1070057/trust-desktop-icons-without-clicking-them-manually-in-ubuntu-18-04-gnome-3 #
#                                                                                                                    #
# Change History                                                                                                     #
# 07/20/2020  Harry Goldschmitt  Original code.                                                                      #
# 09/18/2020  Harry Goldschmitt  Added sourced GMATUtilities.sh and logging                                          #
#                                                                                                                    #
######################################################################################################################
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
# Output trustGMATDesktopIcon.sh command and parameters help info.
#
function usage
{
    cat <<EOF
NAME
     trustGMATDesktopIcon.sh -- attempt to configure Gnome desktop to trust
                                the GMAT icon.

SYNOPSIS
     trustGMATdDesktopIcon.sh [OPTION]

DESCRIPTION
     Attempt to have Gnome trust the GMAT desktop icon.

OPTIONS
     -h, --help
          Display this help
EOF
    return 0
}

options "$@"

# Create an autostart script to run at each run at the first graphic login
mkdir --parents "$HomeDir"/gmat-build 2>&1 | tee --append "$LOG_FILE_NAME"

mkdir --parents "$HomeDir/.config/autostart" || errorExit "Unable to create $HomeDir/.conconfig/autostart"

if ! [ -x "$HomeDir/.config/autostart/GMAT-truster.sh" ]; then

    # Create an autostart script to wait for nautilus-desktop to come up, set the
    # trust property of GMAT.desktop on, and then disable the autostart script by
    # turning off its execute file mode.
    exec 9<<EOF
#!/bin/bash
################################################################################
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

if [ -x "$HOME/Desktop/GMAT.desktop" ]; then

    # Wait for nautilus-desktop to start
    while ! pgrep -f -q 'nautilus-desktop'; do
        sleep 1
    done

    # Trust the GMAT.desktop file
    gio set "$HOME/Desktop/GMAT.desktop" "metadata::trusted" yes

    # Restart nautilus, so that the changes take effect (otherwise we would have to press F5)
    killall nautilus-desktop && nautilus-desktop &

    # Remove executable mode from this script, so that it won't be executed next time
    chmod -x "${0}"

fi
exit 0
EOF

    cat <&9 > "$HomeDir/.config/autostart/GMAT_truster.sh" || errorExit "Unable to create $HomeDir/.config/autostart/GMAT_truster.sh"
    chmod +x "$HomeDir/.config/autostart/GMAT_truster.sh" || errorExit "Unable to set mode to executable for $HomeDir/.config/autostart/GMAT_truster.sh"
fi

# Create a .config/autostart/GMAT_truster.desktop file if needed.
# This causes nautilus to invoke the shell script, if executable, above.

if ! [ -f "$HomeDir/.config/autostart/GMAT_truster.desktop" ]; then

    # Create the autostart desktop file to invoke $HOME/.config/autostart/GMAT-truster.sh at login

    exec 9<<EOF
[Desktop Entry]
Name=Desktop-Truster
Comment=Autostarter to trust all desktop files
Exec=$HOME/.config/autostart/GMAT-truster.sh
Type=Application
EOF

    cat <&9 >"$HomeDir/.config/autostart/GMAT_truster.desktop" || errorExit "Error creating $HomeDir/.config/autostart/GMAT_truster.desktop"
fi

exit 0
