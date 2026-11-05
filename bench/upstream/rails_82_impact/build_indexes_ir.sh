#!/bin/bash
# Cachegrind Ir per call of IndexedRow.build_indexes: (20,000 calls − 0) / 20,000, fixed heap, after 2,000 warmup calls.
# Usage: VALGRIND=path/bin/valgrind build_indexes_ir.sh RUBY "FLAGS" RAILS_WORKTREE COLUMNS
ruby=$1; flags=$2; wt=$3; n=$4
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
ir() { f=$(mktemp); ${VALGRIND:-valgrind} --tool=cachegrind --cache-sim=no --cachegrind-out-file=/dev/null $ruby $flags "$(dirname "$0")/build_indexes_matrix.rb" $wt $n $1 2>$f >/dev/null; grep -o 'I *refs: *[0-9,]*' $f | tr -dc 0-9; rm $f; }
a=$(ir 0); b=$(ir 20000)
echo "$(( (b - a) / 20000 ))"
