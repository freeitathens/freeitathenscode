# " get FreeIT.png, move to common image dir ",
#sudo chown -c root:root FreeIT.png 
locate FreeIT.png |xargs ls -l

egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID && echo -e "\n\e[1;31;47mfstab cannot go on image with local UUID reference\e[0m\n"

echo '<ENTER>'
read xU

# "Remove reference to medibuntu":
egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

# "Use update manager"

sudo apt-get install dialog xscreensaver-gl
# "(64 Mate only): add OnlyIn Mate;"

# "(32 Xfce only)":
#sudo apt-get install gnome-system-tools 
# "(32: save session)"

#sudo add-apt-repository ppa:mozillateam/firefox-next
#sudo add-apt-repository ppa:otto-kesselgulasch/gimp
#sudo apt-get install gimp firefox

sudo apt-get install lm-sensors hddtemp ethtool 

# "Before new image out":
sudo find /root/.pulse /root/.dbus/session-bus -ls -delete
sudo find /root/ -name ".pulse*" -ls -delete
find ~/.ssh -not -type d -ls -delete
# Clear oem .mozilla cache/history

