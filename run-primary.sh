#!/usr/bin/bash

DIR=$1

sleep=60
m=fast

export PGCTLTIMEOUT=3600

DATADIR=/mnt/pgdata/data-primary

pg_ctl -m fast -D $DATADIR stop || true

m=fast

# 100 loops of the primary restarts
for r in $(seq 1 100); do

	echo `date` "start for replica $i"
	pg_ctl -D $DATADIR -l $DIR/pg-primary.log start

	psql test -c "select now(), slot_name, wal_status, (pg_current_wal_lsn() - restart_lsn), pg_size_pretty((pg_current_wal_lsn() - restart_lsn)) from pg_replication_slots";

	echo `date` "pgbench"
	pgbench -c 4 -P 1 -T $((RANDOM % $sleep)) test

	while /bin/true; do

		psql test -c "select now(), slot_name, wal_status, (pg_current_wal_lsn() - restart_lsn), pg_size_pretty((pg_current_wal_lsn() - restart_lsn)) from pg_replication_slots";

		c=$(psql -t -A test -c "select count(*) from pg_replication_slots where wal_status = 'lost'")

		if [ "$c" != "0" ]; then
			break
		fi

		c=$(psql -t -A test -c "select count(*) from pg_replication_slots where (pg_current_wal_lsn() - restart_lsn) > 128*1024*1024")

		if [ "$c" == "0" ]; then
			echo "found lost slot, no point in waiting"
			break
		fi

		if [ "$m" == "fast" ]; then
			m=immediate
		else
			m=fast
		fi

	        echo `date` "stop for primary"
        	pg_ctl -D $DATADIR -m $m -l $DIR/pg-primary.log stop

        	echo `date` "stop for primary"
        	pg_ctl -D $DATADIR -l $DIR/pg-primary.log start

		sleep $((RANDOM % 5 + 1))

	done

	c=$(psql -t -A test -c "select count(*) from pg_replication_slots where wal_status = 'lost'")

	echo `date` "stop for primary"
	pg_ctl -D $DATADIR -m $m -l $DIR/pg-primary.log stop

	if [ "$m" == "fast" ]; then
		m=immediate
	else
		m=fast
	fi

	if [ "$c" != "0" ]; then
		echo "found lost slot, aborting"
		break
	fi

done

touch stop
