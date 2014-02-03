# " get FreeIT.png, move to common image dir ",
#sudo chown -c root:root FreeIT.png 
FIT='FreeIT.png'
locate $FIT |xargs ls -l
echo 'does' $FIT 'file listed appear above?'
read xU

echo 'look for (absence of) local UUID reference for swap in fstab'
egrep -v '^\s*(#|$)' /etc/fstab |grep swap |grep UUID && echo -e "\n\e[1;31;47mfstab cannot go on image with local UUID reference\e[0m\n"
echo '<ENTER>'
read xU

# "Remove reference to medibuntu":
egrep -v '^\s*(#|$)' /etc/apt/sources.list |grep medi && sudo vi /etc/apt/sources.list

echo "Use update manager <PAUSING>"
read xU

sudo apt-get install dialog xscreensaver-gl
# "(64 Mate only): add OnlyIn Mate;"

# "(32 Xfce only)":
sudo apt-get install gnome-system-tools 

sudo apt-get install lm-sensors hddtemp ethtool 
# "(32: save session)"
echo 'Notification to save session'
#ensure existence of : /home/*/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml:    <property name="SessionName" type="string" value="Default"/>

sudo add-apt-repository ppa:mozillateam/firefox-next
sudo add-apt-repository ppa:otto-kesselgulasch/gimp
sudo apt-get install gimp firefox

# "Before new image out":
sudo find /root/.pulse /root/.dbus/session-bus -ls -delete
sudo find /root/.pulse /root/.dbus/session-bus -ls
sudo find /root/ -name ".pulse*" -ls -delete
sudo find /root/ -name ".pulse*" -ls
find ~/.ssh -not -type d -ls -delete
find ~/.ssh -not -type d -ls
echo 'Clearing cups settings (if any)'
for CUPSDEF in /etc/cups/{classes,printers,subscriptions}.conf; do if [ -f ${CUPSDEF}.O ];then sudo cp -v ${CUPSDEF}.O $CUPSDEF;bn=$(basename $CUPSDEF);sudo find /etc/cups/ -name "${bn}*" -exec sudo md5sum {} \; -exec sudo ls -l {} \; ;else :;fi;done

echo "Remove-ing QC test result files"
rm -vi ${HOME}{,/Desktop}/QC*log 2>/dev/null
find $HOME -name 'QC*log' -ls

# Additional options
#swapoff --all --verbose
echo 'Composition of fstab:'
grep -E -v '^\s*(#|$)' /etc/fstab
#swapon --all --verbose
swapon --summary --verbose
#udevadm info --query=env --name=/dev/sda1 |grep UUID
#udevadm info --query=env --name=/dev/sda2 |grep UUID
free
locate iguazu
lsb_release -a
#locate xorg.conf

