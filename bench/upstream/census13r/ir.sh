#!/usr/bin/env bash
# Exploratory Ir per call: ir.sh RUBY SCRIPT N  (script defines $op; runs it N times in Array#cycle)
ruby=$1; script=$2; n=$3
run() {
  /home/user/w/valgrind-brk512/bin/valgrind --tool=callgrind --toggle-collect=rb_ary_cycle --callgrind-out-file=/tmp/irx.%p.out \
    $ruby -e "load '$script'; 3000.times { \$op.call }; GC.start; GC.disable; [1].cycle($1) { \$op.call }" 2>&1 | grep -o 'Collected : [0-9]*' | grep -o '[0-9]*'
}
a=$(run "$n"); b=$(run 0)
echo "$(( (a - b) / n )) Ir/call"
