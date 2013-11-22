#!/bin/sh

cat > "/home/oem/Desktop/Prepare for end user.desktop" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Terminal=false
Icon[en_US]=gnome-panel-launcher
Exec=oem-config-prepare
Name[en_US]=Prepare for end user
Name=Prepare for end user
Icon=gnome-panel-launcher
EOF

export http_proxy=http://server:9999
aptitude update
aptitude -y install b43-fwcutter
aptitude -y dist-upgrade
aptitude -y install atomix audacity avidemux  blender dia-gnome edubuntu-addon-kde flashplugin-nonfree freemind gcompris gcompris-sound-en gcompris-sound-es gimp-gap gpaint gstreamer0.10-ffmpeg gstreamer0.10-plugins-bad gstreamer0.10-plugins-bad-multiverse gstreamer0.10-plugins-ugly gstreamer0.10-plugins-ugly-multiverse icedtea6-plugin inkscape kompozer language-pack-es language-support-es libavcodec-unstripped-51 libdvdread3 libmp3lame0 msttcorefonts oem-config qcad scribus secure-delete tuxmath tuxpaint tuxpaint-stamps-default tuxtype unrar

echo "If the sotware installed successfully, prepare for end user the shut down"

