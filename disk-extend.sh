#!/bin/bash
#####################################################################################################
#                                   disk-extend.sh                                                  #
#                                                                                                   #
# Ubuntu shell script to run as a Vgrant provision script, to extend the size of a disk file system #
# It is based on a script posted by Marc Brandner on his blog:                                      #
# https://marcbrandner.com/blog/increasing-disk-space-of-a-linux-based-vagrant-box-on-provisioning/ #
#                                                                                                   #
# Change History                                                                                    #
# 10/07/2020  Harry Goldschmitt  Original code.                                                     #
#                                                                                                   #
#####################################################################################################
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

echo "> Installing required tools for file system management"
if  [ -n "$(command -v yum)" ]; then
    echo ">> Detected yum-based Linux"
    sudo yum makecache
    sudo yum install -y util-linux
    sudo yum install -y lvm2
    sudo yum install -y e2fsprogs
fi
if [ -n "$(command -v apt-get)" ]; then
    echo ">> Detected apt-based Linux"
    sudo apt-get --quiet --quiet update --yes
    sudo apt-get --quiet --quiet install --yes fdisk
    sudo apt-get --quiet --quiet install --yes lvm2
    sudo apt-get --quiet --quiet install --yes e2fsprogs
fi
ROOT_DISK_DEVICE="/dev/sda"
ROOT_DISK_DEVICE_PART="/dev/sda1"
LV_PATH=$(sudo lvdisplay --colon | sed --quiet 1p | awk --field-separator ":" '{print $1;}')
FS_PATH=$(df / | sed --quiet 2p | awk '{print $1;}')
ROOT_FS_SIZE=$(df --human-readable / | sed --quiet 2p | awk '{print $2;}')
echo "The root file system (/) has a size of $ROOT_FS_SIZE"
echo "> Increasing disk size of $ROOT_DISK_DEVICE to available maximum"
sudo fdisk $ROOT_DISK_DEVICE <<EOF
d
n
p
1
2048

no
w
EOF
sudo pvresize $ROOT_DISK_DEVICE_PART
sudo lvextend --extents +100%FREE "$LV_PATH"
sudo resize2fs -p "$FS_PATH"
ROOT_FS_SIZE=$(df --human-readable / | sed --quiet 2p | awk '{print $2;}')
echo "The root file system (/) has a size of $ROOT_FS_SIZE"
exit 0
