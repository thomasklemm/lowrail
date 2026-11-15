#!/bin/bash
# run.sh RUBY TREE JITFLAGS -> Ir per call (N=21000 minus N=1000, /20000)
R=$1; T=$2; shift 2
C=${CONCURRENT_RUBY_LIB:?path to concurrent-ruby/lib/concurrent-ruby}
ir() { N=$1 RUBYLIB=$T/activesupport/lib:$C valgrind --tool=callgrind --callgrind-out-file=/dev/null $R "${@:2}" oo1_micro.rb 2>&1 | grep -o 'Collected : [0-9]*' | grep -o '[0-9]*$'; }
a=$(ir 1000 "$@"); b=$(ir 21000 "$@"); echo "scale=1; ($b-$a)/20000" | bc
