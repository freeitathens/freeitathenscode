#!/bin/bash
if [ 0 -lt $(id |grep -o -P '^uid=\d+' |cut -f2 -d=) ]
then
	echo 'Hello User: Please rerun with sudo or root'
	exit 4
fi

# Script for running when updating an existing image

#  Not doing svn server (but thru svn+ssh)
#export http_proxy=http://server:3142 

svn update ~oem/freeitathenscode

apt-get update
apt-get dist-upgrade
apt-get clean

rm /etc/udev/rules.d/*
