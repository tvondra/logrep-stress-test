#!/usr/bin/bash

sleep=30

export PGCTLTIMEOUT=3600


while /bin/true; do

	#sleep $((RANDOM % $sleep))

	if [ -f "stop" ]; then
		break
	fi

	psql test -c "checkpoint"

done
