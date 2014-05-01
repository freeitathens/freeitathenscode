#!/bin/bash
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
	echo 'Hello User: Please rerun with sudo or root'
	exit 4
fi

# Script for running when creating an image from scratch

#export http_proxy=http://server:3142

# install packages that download other files
# bypass proxy because of that
#http_proxy='' apt-get -y install b43-fwcutter ttf-mscorefonts-installer

# install spanish language support
apt-get -y install language-support-es language-pack-es language-pack-gnome-es 
#libreoffice.org-l10n-es

# install misc packages
# dialog is needed for qc process
apt-get -y install dialog vim gimp audacity scribus ubuntu-restricted-extras

# install educational packages
# skip recommends so pull in less kde infrastructure
apt-get --no-install-recommends -y install ubuntu-edu-preschool ubuntu-edu-primary ubuntu-edu-secondary ubuntu-edu-tertiary gcompris-sound-en 

# remove installers
apt-get clean

# necessary for our zonet zew2500 usb wifi dongles to work
echo "blacklist rt2800usb" > /etc/modprobe.d/blacklist-frita.conf

# checkout our svn and link our scripts to convenient locations
# svn seems unaffected by http_proxy
svn checkout http://freeitathenscode.googlecode.com/svn/trunk/ ~oem/freeitathenscode
mkdir ~oem/bin
ln -s ~oem/freeitathenscode/QC_Process/QC.sh ~oem/bin/QC.sh
ln -s ~oem/freeitathenscode/QC_Process/Quality\ Control.desktop ~/Desktop/Quality\ Control.desktop
ln -s ~oem/freeitathenscode/QC_Process/Disable\ 3D.desktop ~/Desktop/Disable\ 3D.desktop

# FreeIT branding 
cp ~oem/freeitathenscode/image_scripts/FreeIT.png /usr/share/backgrounds/
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --type string --set /desktop/gnome/background/picture_filename "/usr/share/backgrounds/FreeIT.png"
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --type string --set /desktop/gnome/background/picture_options "zoom"
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --type string --set /desktop/gnome/background/color_shading_type "solid"
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --type string --set /desktop/gnome/background/primary_color "#dddddddddddd"

# copy slideshow onto computer
cp -r ~oem/freeitathenscode/intro_ubuntu /usr/local/share/
# create link to slideshow in all users home folders so they can replay it
ln -s /usr/local/share/intro_ubuntu/intro_ubuntu_1004.odp /etc/skel/
# copy script to play slideshow once onto system
cp ~oem/freeitathenscode/image_scripts/watch_intro /usr/local/bin/
chmod +x /usr/local/bin/watch_intro
# copy file that autostarts slideshow when user logs in onto system
cp ~oem/freeitathenscode/image_scripts/intro_ubuntu.desktop /etc/xdg/autostart/

bash ~oem/freeitathenscode/image_scripts/image_update.sh
