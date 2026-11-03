#!/bin/bash
# ir.sh RAILS CASE [RUBY_OPTS] : Callgrind Ir per call of CASE on the Rails checkout RAILS.
# BUNDLE= (empty) skips bundle exec, for a Ruby with the gems installed.
# Runs bench.rb with N and with 0 calls and prints (Ir(N) - Ir(0)) / N.
set -e
rails=$1; c=$2; opts=$3
case $c in pre_*) n=20000;; *) n=1000;; esac
here=$(cd "$(dirname "$0")" && pwd)
run() {
  (cd "$rails" && RAILS=$rails ${BUNDLE-bundle exec} valgrind --tool=callgrind --callgrind-out-file=/dev/null \
    --smc-check=all ruby $opts "$here/bench.rb" ir "$c" "$1" 2>&1) |
    grep -o 'Collected : [0-9]*' | tail -1 | grep -o '[0-9]*'
}
a=$(run 0); b=$(run $n)
echo "$c ${opts:-interp} $(( (b - a) / n ))"
