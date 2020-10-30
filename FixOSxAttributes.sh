################################################################################
#                            fixOSxAttributes.sh                               #
#                                                                              #
# Ubuntu shell script remove OSx quarantine extended attribute added by        #
# Apple at random times, to random files.                                      #
#                                                                              #
# Change History                                                               #
# 08/02/2020  Harry Goldschmitt  Original code.                                #
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

# Operation: cd to a base directory and issue this script to wipe out all
#            extended attributes, recursively.

sudo xattr -rc .
sudo chmod -R -N .
