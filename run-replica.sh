#!/usr/bin/bash

sleep=10
m=fast

DIR=$1
REPLICA=$2

export PGCTLTIMEOUT=3600

DATADIR=/mnt/pgdata/data-replica-$REPLICA

pg_ctl -m fast -D $DATADIR stop || true

m=fast

while /bin/true; do

	#sleep=$((sleep+15))
	if [ -f "stop" ]; then
		break
	fi

	echo `date` "start for replica $i"
	pg_ctl -D $DATADIR -l $DIR/pg-$REPLICA.log start

	sleep $((RANDOM % $sleep))

	echo `date` "stop for replica $i"
	pg_ctl -D $DATADIR -m $m -l $DIR/pg-$REPLICA.log stop

	#sleep $((RANDOM % $sleep))

	if [ "$m" == "fast" ]; then
		m=immediate
	else
		m=fast
	fi

done
