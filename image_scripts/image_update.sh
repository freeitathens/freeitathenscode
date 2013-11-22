#!/bin/bash

# Script for running when updating an existing image

export http_proxy=http://server:3142 

svn update ~oem/freeitathenscode

apt-get update
apt-get dist-upgrade
apt-get clean

rm /etc/udev/rules.d/*
