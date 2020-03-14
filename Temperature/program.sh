#!/bin/bash

if [ -n "$1" ] ; then first=$1
else first="0"
fi

job=0
for i in /dev/ttyUSB?; do 
    (( job++ ))
    n=${i/\/dev\/ttyUSB/}
    n=$((n+first))
    echo "Programming node $n attached to $i"
    make telosb reinstall,$n bsl,$i &> /tmp/program_$n.log &
done

wait %$job

echo "Done."
