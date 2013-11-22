#!/bin/bash


# THIS SCRIPT IS DANGEROUS!
# UNCOMMENT LINE 56 TO ARM.


declare -a HARDDISKS
i=0

findharddisks() {

# Search IDE.

for x in {a..f}; do

if [ -a /dev/hd$x ]; then

   HARDDISKS[$i]=hd$x
   ((i++))

fi

done

# Search SATA.

for x in {a..d}; do

if [ -a /dev/sd$x ]; then

   HARDDISKS[$i]=sd$x
   ((i++))

fi

done

echo -e "Found disks:\n"

for a in "${HARDDISKS[@]}"; do

echo /dev/$a

done

}

zeroharddisks() {

echo -e "***** STARTING DISK WIPES *****\n"

for a in "${HARDDISKS[@]}"; do
   
   echo "Writing zeros to /dev/$a..."
#   time dd if=/dev/zero of=/dev/$a 2>&1 | tee /tmp/$a
   echo -e "Done.\n"

done

}

case "$1" in

    wipe)
	findharddisks
	echo
	zeroharddisks
         ;;
    *)
	findharddisks
         ;;
esac

exit 0
