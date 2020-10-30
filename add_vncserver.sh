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
# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-18-04#step-4-%E2%80%94-running-vnc-as-a-system-service

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

SCRIPT_DIRECTORY="/vagrant"
[ -d $SCRIPT_DIRECTORY ] || \
    SCRIPT_DIRECTORY="$HOME"

[ -r "$SCRIPT_DIRECTORY/GMATUtilities.sh" ] || {
    echo "GMATUtilities.sh not found or readable" >&2;
    exit 1; }

# shellcheck source=./GMATUtilities.sh
source "$SCRIPT_DIRECTORY/GMATUtilities.sh"

typeset -i defaultPort=5901
typeset -i vncPort=$defaultPort

if [ -f "/vagrant/Vagrantfile" ]; then
    if grep -q vnc "/vagrant/Vagrantfile"; then
        vncPort=$(grep -vE '^ *#' /vagrant/Vagrantfile | grep -v '^ *$' | grep -E 'vnc' | sed -e 's/^.*host: //' | sed -e 's/,.*//'| head -1) || \
            errorExit "Could not parse /vagrant/Vagrantfile"
    fi
fi

# Install expect for this script
echo "Installing expect" | tee --append "$LOG_FILE_NAME"
sudo --preserve-env /bin/bash -c 'apt-get --quiet --quiet install --yes expect 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error installing expect"
fi

# Install needed packages
echo "Installing vnc prerequisite packages" | tee --append "$LOG_FILE_NAME"
sudo --preserve-env /bin/bash -c 'apt-get --quiet --quiet install --yes xfce4 xfce4-goodies 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error installing vnc prerequesits"
fi

echo "Installing tightvncserver package" | tee --append "$LOG_FILE_NAME"
sudo --preserve-env /bin/bash -c 'apt-get --quiet --quiet install --yes tightvncserver 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
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

/usr/bin/expect <&9 2>&1;  echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error running vncserver via expect"
fi

# Stop the started vncserver :1
vncserver -kill :1 2>&1 ;echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error running vncserver -kill"
fi

# Backup the existing xstartup script, if any, the first time through this script
if ! [ -f "$HomeDir/.vnc/xstartup.bak" ]; then
    mv --force "$HomeDir/.vnc/xstartup" "$HomeDir/.vnc/xstartup.bak" 2>&1;  echo "$?" >"$RCFile" | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
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

cat <&9 2>&1 >"$HomeDir/.vnc/xstartup" ;echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Unable to create $HomeDir/.vnc/xstartup script"
fi

# Make xstartup executable
sudo --preserve-env /bin/bash -c 'chmod +x $HomeDir/.vnc/xstartup 2>&1 ;echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Unable to make $HomeDir/.vnc/xstartup script executable"
fi

# Restart the vncserver to test it comes up
vncserver 2>&1 ; echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Unable to restart vncserver, using $HomeDir/.vnc/xstartup"
fi

# Create the systemd VNC server service file
echo "Creating the systemd VNC server service file" | tee --append "$LOG_FILE_NAME"
if ! [ -f /etc/systemd/system/vncserver@.service ]; then
    export serviceFile
    serviceFile=$(mktemp) 2>&1; echo "$?" >"$RCFile" | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
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

    cat <&9 2>&1 >"$serviceFile"; echo "$?" >"$RCFile" | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Error creating service file"
    fi

    chmod 644 "$serviceFile" 2>&1; echo "$?" >"$RCFile" | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Error setting service file mode"
    fi

    sudo  --preserve-env bash -c 'chown root:root "$serviceFile" 2>&1 ;echo "$?" >"$RCFile"' | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Unable to change owner of vncserver@.service to root"
    fi

    export serviceDestFile
    serviceDestFile='/etc/systemd/system/vncserver@.service'

    sudo  --preserve-env bash -c 'mv --force "$serviceFile" "$serviceDestFile" 2>&1; echo "$?" >"$RCFile"' | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Error moving vncserver@.service file"
    fi

    # Enable vncserver@ service
    sudo  --preserve-env bash -c 'systemctl daemon-reload  2>&1 ;echo "$?" >"$RCFile"' | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Error in daemon-reload"
    fi

    sudo  --preserve-env bash -c 'systemctl enable vncserver@1 2>&1 ;echo "$?" >"$RCFile"' | \
        tee --append "$LOG_FILE_NAME"
    if [[ $(cat "$RCFile") != 0 ]]; then
        errorExit "Error enabling vncserver@1"
    fi
fi

echo "Validating vncserver :1 can be started via systemctl" | tee --append "$LOG_FILE_NAME"
# Stop any possibly started vncserver :1
vncserver -kill :1 2>&1 ;echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error running vncserver -kill"
fi

sudo --preserve-env /bin/bash -c 'systemctl start vncserver@1 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error using systemctl to start vncserver@1"
fi

sudo --preserve-env /bin/bash -c 'systemctl status vncserver@1 2>&1; echo "$?" >"$RCFile"' | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error service vncserver@1 did not start correctly"
fi

[ -x "$SCRIPT_DIRECTORY/createGMATLauncher.sh" ] || errorExit "Unable to locate /vagrant/createGMATLauncher.sh"

"$SCRIPT_DIRECTORY/createGMATLauncher.sh" 2>&1 ;echo "$?" >"$RCFile" | \
    tee --append "$LOG_FILE_NAME"
if [[ $(cat "$RCFile") != 0 ]]; then
    errorExit "Error running /vagrant/createGMATLauncher.sh"
fi

echo "VNC has been added to this vagrant box. It can be accessed from a VNC viewer by connecting to localhost:$vncPort." | tee --append "$LOG_FILE_NAME"
echo "Log in as user vagrant with password vagrant." | tee --append "$LOG_FILE_NAME"

exit 0
