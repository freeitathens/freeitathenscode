#!/bin/bash
sudo sed -i "/manual/d" /etc/network/interfaces
sudo ifconfig eth0 up
sudo dhclient eth0
sudo http_proxy=http://server:9999 aptitude -y update
sudo http_proxy=http://server:9999 aptitude -y dist-upgrade
sudo http_proxy=http://server:9999 aptitude install oem-config-gtk ubuntu-restricted-extras edubuntu-desktop b43-fwcutter
sudo oem-config-prepare
