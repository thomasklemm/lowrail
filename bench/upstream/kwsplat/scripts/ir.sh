#!/bin/bash
# ir.sh SCRIPT RUBY... -> Ir per call for sizes 0..9: the difference between
# N=120000 and N=20000 runs, divided by 100000. GC is disabled by the script.
script=$1; shift
for r in "$@"; do
  for s in 0 1 2 3 5 8 9; do
    v=()
    for n in 20000 120000; do
      v+=($(SIZE=$s N=$n valgrind --tool=callgrind --callgrind-out-file=/dev/null "$r" "$script" 2>&1 | grep -o "Collected : [0-9]*" | grep -o "[0-9]*"))
    done
    echo "$r $s $(( (v[1]-v[0]) / 100000 ))"
  done
done
