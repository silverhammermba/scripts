#!/bin/bash
# simpler version of reflector

if [ $# -ne 3 ]; then
	echo "Usage: $0 COUNTRY SCORE SPEED"
	echo
	echo "Rank the top SCORE scoring mirrors for COUNTRY and output the SPEED fastest."
	exit 1
fi

# get US mirrorlist by status
# strip off header
# uncomment mirrors
# remove comments
# limit to 10 highest scoring mirrors
# get top 5 by connection speed

curl -s "https://www.archlinux.org/mirrorlist/?country=$1&use_mirror_status=on" |\
	tail -n +7 |\
	cut -c 2- |\
	grep -v ^# |\
	head -n "$2" |\
	rankmirrors -n "$3" -
