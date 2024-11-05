#!/usr/bin/bash

DIR=$1
REPLICAS=$2
SCALE=$3

killall -9 postgres
rm -Rf /mnt/pgdata/data*

pg_ctl -D /mnt/pgdata/data-primary init

echo 'wal_level = logical' >> /mnt/pgdata/data-primary/postgresql.conf 2>&1
echo 'max_wal_size = 128MB' >> /mnt/pgdata/data-primary/postgresql.conf 2>&1

pg_ctl -D /mnt/pgdata/data-primary -l $DIR/pg.log start

createdb test
pgbench -i -s $SCALE test

psql test -c 'create publication p for all tables'

pg_dump -s test > schema.sql

for s in $(seq 1 $REPLICAS); do

	p=$((6000+s))
	pg_ctl -D /mnt/pgdata/data-replica-$s init

	echo "port = $p" >> /mnt/pgdata/data-replica-$s/postgresql.conf
	echo "max_wal_size = 128MB" >> /mnt/pgdata/data-replica-$s/postgresql.conf

	pg_ctl -D /mnt/pgdata/data-replica-$s -l $DIR/pg-$s.log start

	createdb -p $p test
	psql -p $p test < schema.sql

	psql -p $p test -c "create subscription s$s connection 'host=localhost dbname=test user=tomas port=5432' publication p"

done

# wait for replicas to catch up
for s in $(seq 1 $REPLICAS); do

	p=$((6000+s))

	while /bin/true; do

		c=$(psql -t -A -p $p test -c "select count(*) from pg_subscription_rel where srsubstate != 'r'")

		if [ "$c" == "0" ]; then
			break
		fi

		sleep 1

	done

done
