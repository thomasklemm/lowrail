#!/usr/bin/env bash
# accept.sh APP WORKLOAD STRICT N -> Ir per request (N minus 0)
cd /home/user/workspace/repo
. bench/upstream/census12/heap.sh
run() { WRAP="/home/user/w/valgrind-brk512/bin/valgrind --tool=callgrind --toggle-collect=rb_ary_cycle --callgrind-out-file=/tmp/acc.%p.out" mise exec ruby@4.0.10 -- ruby bench/upstream/census13r/run_in_app.rb "$1" rails/rails@2e299253f942ab94041cc6f210ac9d33884c210d 4.0.10 bench/upstream/census13r/accept_share.rb "$2" "$3" "$4" 2>&1 | grep -o 'Collected : [0-9]*' | tail -1 | grep -o '[0-9]*'; }
a=$(run "$1" "$2" "$3" "$4"); b=$(run "$1" "$2" "$3" 0)
echo "$1 | $2 | strict=$3 | $(( (a - b) / $4 )) Ir/request"
