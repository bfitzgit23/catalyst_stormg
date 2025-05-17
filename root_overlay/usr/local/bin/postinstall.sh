#!/bin/bash -e
#
##############################################################################
#
#  PostInstall is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your discretion) any later version.
#
#  PostInstall is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
##############################################################################
echo "FONT=ter-p16n" >> /etc/vconsole.conf

rm -rf /usr/share/calamares
rm -rf $HOME/xinnixos-user/Desktop/calamares.desktop
#rm -rf $HOME/xinnixos-user/Desktop/Install XinnixOS-CLI.desktop
#rm -rf /usr/bin/install-xinnixos.sh

# Continue cleanup
rm /usr/local/bin/postinstall.sh
