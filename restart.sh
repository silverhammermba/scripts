#!/usr/bin/sh

if [ $# -eq 0 ]
then
	echo "Usage: $0 CMD"
	exit 1
fi

while [ 1 ]
do
	if ! eval $@
	then
		echo $?
		exit $?
	fi
	sleep 10
done
