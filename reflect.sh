#!/bin/bash
# simpler version of reflector

if [ $# -ne 3 ]; then
	echo >&2 "Usage: $0 COUNTRY SCORE SPEED"
	echo >&2
	echo >&2 "Rank the top SCORE scoring mirrors for COUNTRY and output the SPEED fastest."
	exit 1
fi

# get $1 mirrorlist by status
# strip off header
# uncomment mirrors
# remove comments
# limit to $2 highest scoring mirrors
# get top $3 by connection speed

curl -s "https://www.archlinux.org/mirrorlist/?country=$1&use_mirror_status=on" |\
	tail -n +7 |\
	cut -c 2- |\
	grep -v ^# |\
	head -n "$2" |\
	rankmirrors -n "$3" -
