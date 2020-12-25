#!/bin/bash

################################################################################
#                               add_vncserver.sh                               #
#                                                                              #
# Ubuntu shell script to install a VNC server on a Vagrant Ubuntu 18.04 box.   #
#                                                                              #
# Change History                                                               #
# 07/20/2020  Harry Goldschmitt  Original code.                                #
# 09/18/2020  Harry Goldschmitt  Added sourced GMATUtilities.sh, logging, and  #
#                                altered logic from Digital Ocean              #
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

# See:
# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-18-04
#           and
# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-20-04

################################################################################
#
# Script - add_vncserver.sh
#
# Purpose: Add a vnc server environment to Ubuntu 18.04
#
# Exits:
#    0 - success
#    1 - failure
#
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
# Output add_vncserver.sh command and parameters help info.
#
function usage
{
    cat <<EOF
NAME
     add_vncserver.sh -- add a vnc server to the system.

SYNOPSIS
     add_vncserver.sh [OPTION]

DESCRIPTION
     Add an VNC server.

OPTIONS
     -h, --help
          Display this help
EOF
    return 0
}

options "$@"

typeset -i defaultPort=5901
typeset -i vncPort=$defaultPort

if [ -f "/vagrant/Vagrantfile" ]; then
    if grep -q vnc "/vagrant/Vagrantfile"; then
        vncPort=$(grep -vE '^ *#' /vagrant/Vagrantfile | grep -v '^ *$' | grep -E 'vnc' | sed -e 's/^.*host: //' | sed -e 's/,.*//'| head -1) || \
            errorExit "Could not parse /vagrant/Vagrantfile"
    fi
fi

# Install needed packages
echo "Installing vnc prerequisite packages" | tee --append "$LOG_FILE_NAME"
if ! runAPTGet xubuntu-desktop; then
    errorExit "Error installing vnc prerequesits"
fi

# Reconfigure or remove buggy packages
echo "Reconfiguring or emoving packages that crash under VNC" | tee --append "$LOG_FILE_NAME"
systemctl --user mask tracker-store.service \
    tracker-miner-fs.service \
    tracker-miner-rss.service \
    tracker-extract.service \
    tracker-miner-apps.service \
    tracker-writeback.service 2>&1 | tee --append "$LOG_FILE_NAME"
RC=${PIPESTATUS[0]}
if ! [[ $RC ]]; then
    errorExit "Error removing tracker packages for user vagrant"
fi

if ! runUnderSUDO apt-get purge blueman -y ; then
    errorExit "Error purging blueman package"
fi

if ! runUnderSUDO apt-get purge xiccd -y ; then
    errorExit "Error purging xiccd package"
fi

if ! runUnderSUDO apt-get purge xfce4-power-manager -y ; then
    errorExit "Error purging xiccd package"
fi

echo "Creating the polkit allow-color file" | tee --append "$LOG_FILE_NAME"
if ! [ -f  /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla ]; then
    export polkitFile
    polkitFile=$(mktemp)
    if ! [[ $? ]]; then
        errorExit "polkit mktemp failure"
    fi

    exec 9<<EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

    cat <&9 2>&1 >"$polkitFile" | tee --append "$LOG_FILE_NAME"
    RC=${PIPESTATUS[0]}
    if ! [[ $RC ]]; then
        errorExit "Error creating polkit file"
    fi

    chmod 644 "$polkitFile" 2>&1 | tee --append "$LOG_FILE_NAME"
    RC=${PIPESTATUS[0]}
    if ! [[ $RC ]]; then
        errorExit "Error setting polkit file mode"
    fi

    if ! runUnderSUDO chown root:root "$polkitFile" ; then
        errorExit "Unable to change owner of $polkitFile to root"
    fi

    export polkitDestFile
    polkitDestFile="/etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla"

    if ! runUnderSUDO mv --force "$polkitFile" "$polkitDestFile" ; then
        errorExit "Error moving $polkitDestFile file"
    fi
fi

# Install expect for this script
echo "Installing expect" | tee --append "$LOG_FILE_NAME"
if ! runAPTGet expect; then
    errorExit "Error installing expect"
fi

echo "Installing tightvncserver package" | tee --append "$LOG_FILE_NAME"
if ! runAPTGet tightvncserver; then
    errorExit "Error installing tightvncserver package"
fi

echo "Configure the VNC server" | tee --append "$LOG_FILE_NAME"
# Create vnc initial confirguation for vagrant user
echo "Creating vagrant user initial configuration" | tee --append "$LOG_FILE_NAME"

exec 9<<EOF
spawn /usr/bin/vncserver
expect "Password:"
send "vagrant\r"
expect "Verify:"
send "vagrant\r"
expect "Would you like to enter a view-only password (y/n)?"
send "n\r"
expect eof
catch wait result
EOF

/usr/bin/expect <&9 2>&1 | tee --append "$LOG_FILE_NAME"
RC=${PIPESTATUS[0]}
if ! [ "$RC" ]; then
    errorExit "Error running vncserver via expect"
fi

# Stop the started vncserver :1
vncserver -kill :1 2>&1 | tee --append "$LOG_FILE_NAME"
RC=${PIPESTATUS[0]}
if ! [[ "$RC" ]]; then
    errorExit "Error running vncserver -kill"
fi

# Backup the existing xstartup script, if any, the first time through this script
if ! [ -f "$HomeDir/.vnc/xstartup.bak" ]; then
    mv --force "$HomeDir/.vnc/xstartup" "$HomeDir/.vnc/xstartup.bak" 2>&1 | tee --append "$LOG_FILE_NAME"
    RC=${PIPESTATUS[0]}
    if ! [[ "$RC" ]]; then
        errorExit "Error backing up $HomeDir/.vnc/xstartup.bak"
    fi
fi

# Create vagrant's xstartup script
# Use $HOME instead of $HomeDir, since this is an independent script
exec 9<<EOF
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF

cat <&9 2>&1 >"$HomeDir/.vnc/xstartup" | tee --append "$LOG_FILE_NAME"
RC=${PIPESTATUS[0]}
if ! [[ "$RC" ]]; then
    errorExit "Unable to create $HomeDir/.vnc/xstartup script"
fi

# Make xstartup executable
if ! runUnderSUDO chmod +x "$HomeDir/.vnc/xstartup"; then
    errorExit "Unable to make $HomeDir/.vnc/xstartup script executable"
fi

VNCServerParms=""
case "$UBUNTU_RELEASE" in
    18.04 )
        ;;
    20.04 )
        VNCServerParms="-localhost"
        if ! runUnderSUDO  ufw allow 5901; then
            errorExit "Error with fw allow 5901"
        fi
        ;;
    * )
        errorExit "Unknown release - $UBUNTU_RELEASE"
        ;;
esac

# Restart the vncserver to test it comes up
vncserver $VNCServerParms 2>&1 | tee --append "$LOG_FILE_NAME"
RC=${PIPESTATUS[0]}
if ! [[ $RC ]]; then
    errorExit "Unable to restart vncserver, using $HomeDir/.vnc/xstartup"
fi

# Create the systemd VNC server service file
echo "Creating the systemd VNC server service file" | tee --append "$LOG_FILE_NAME"
if ! [ -f /etc/systemd/system/vncserver@.service ]; then
    export serviceFile
    serviceFile=$(mktemp)
    if ! [[ $? ]]; then
        errorExit "mktemp failure"
    fi

    exec 9<<EOF
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=vagrant
Group=vagrant
WorkingDirectory=/home/vagrant

PIDFile=/home/vagrant/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i >/dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1280x800 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

    cat <&9 2>&1 >"$serviceFile" | tee --append "$LOG_FILE_NAME"
    RC=${PIPESTATUS[0]}
    if ! [[ $RC ]]; then
        errorExit "Error creating service file"
    fi

    chmod 644 "$serviceFile" | tee --append "$LOG_FILE_NAME"
    RC=${PIPESTATUS[0]}
    if ! [[ $RC ]]; then
        errorExit "Error setting service file mode"
    fi

    if ! runUnderSUDO chown root:root "$serviceFile" ; then
        errorExit "Unable to change owner of vncserver@.service to root"
    fi

    export serviceDestFile
    serviceDestFile='/etc/systemd/system/vncserver@.service'

    if ! runUnderSUDO mv --force "$serviceFile" "$serviceDestFile" ; then
        errorExit "Error moving vncserver@.service file"
    fi

    # Enable vncserver@ service
    if ! runUnderSUDO systemctl daemon-reload ; then
        errorExit "Error in daemon-reload"
    fi

    if ! runUnderSUDO 'systemctl enable vncserver@1.service'; then
        errorExit "Error enabling vncserver@1"
    fi
fi

echo "Validating vncserver :1 can be started via systemctl" | tee --append "$LOG_FILE_NAME"
# Stop any possibly started vncserver :1
vncserver -kill :1 2>&1 | tee --append "$LOG_FILE_NAME"
if ! [[ $? ]]; then
    errorExit "Error running vncserver -kill"
fi

if ! runUnderSUDO systemctl start vncserver@1 ; then
    errorExit "Error using systemctl to start vncserver@1"
fi

if ! runUnderSUDO systemctl status vncserver@1 ; then
    errorExit "Error service vncserver@1 did not start correctly"
fi

[ -x "$SCRIPT_DIRECTORY/createGMATLauncher.sh" ] || errorExit "Unable to locate $SCRIPT_DIRECTORY/createGMATLauncher.sh"

"$SCRIPT_DIRECTORY/createGMATLauncher.sh" 2>&1 | tee --append "$LOG_FILE_NAME"
if ! [[ $? ]]; then
    errorExit "Error running /vagrant/createGMATLauncher.sh"
fi

echo "VNC has been added to this vagrant box. It can be accessed from a VNC viewer by connecting to localhost:$vncPort." | tee --append "$LOG_FILE_NAME"
echo "Log in as user vagrant with password vagrant." | tee --append "$LOG_FILE_NAME"

runUnderSUDO shutdown --reboot "+1" "Restarting to enable VNC server"

exit 0
