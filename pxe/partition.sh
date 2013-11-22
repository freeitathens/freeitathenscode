#!/bin/sh
parted -s /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary linux-swap 1MB 970MB 
parted -s -a optimal /dev/sda mkpart primary ext3 970MB 100%
