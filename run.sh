#!/usr/bin/bash

while /bin/true; do

	killall -9 postgres
	ps ax | grep 'run-' | awk '{print $1}' | xargs kill

	rm -f *.log stop

	r=$((RANDOM % 3 + 1))
	s=$((RANDOM % 1000 + 500))

	d=$(date +%Y%m%d-%H%M)-$r-$s

	mkdir $d

	echo `date` $d "run scale $s replicas $r"

	./setup.sh $d $r $s > $d/setup.log 2>&1

	./run-primary.sh $d > $d/primary.log 2>&1 &

	./run-checkpoints.sh $d > $d/checkpoints.log 2>&1 &

	for r in $(seq 1 $r); do
		./run-replica.sh $d $r > $d/replica-$r.log 2>&1 &
	done

	wait

	rm stop

done
