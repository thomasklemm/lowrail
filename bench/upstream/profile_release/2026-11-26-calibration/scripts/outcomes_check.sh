#!/usr/bin/env bash
# outcomes_check.sh APP: per-test outcomes of both runs of every capture against the plain run (sweep's outcomes.rb;
# schema-load timing lines "-> 0.0034s" dropped).
set -u
export PATH=$(~/.local/bin/mise where ruby@4.0.7)/bin:$PATH
O=/home/user/workspace/repo/bench/upstream/oss_profile_sweep_1/outcomes.rb out=/home/user/cal/out/$1
# Minitest apps: mt_outcomes.rb; Forem (rspec documentation): the sweep's outcomes.rb.
[ "$1" = forem ] || O=$(cd "$(dirname "$0")" && pwd)/mt_outcomes.rb
# Postgres notices on stderr can split a minitest result line ("... = WARNING:  there is no transaction in progress\n2.19 s = .").
f() { local log=$1; shift; ruby -e 'print File.binread(ARGV[0]).gsub(/(?:WARNING|FATAL|NOTICE):  [^\n]*\n/, "")' "$log" > /tmp/cal/clean.log
  ruby $O /tmp/cal/clean.log "$@" | grep -vE '^\s+-> [0-9.]+s$'; }
f "$out/plain.log" > /tmp/cal/$1-plain.out
echo "$1 plain: $(wc -l < /tmp/cal/$1-plain.out) outcomes, $(grep -cE ' (F|E|FAILED)$' /tmp/cal/$1-plain.out) failed"
for s in ${STEPS:-s1 s2 s3 s4 s5 s6 s7 s8 planted planted2}; do
  [ -f "$out/$s.log" ] || continue
  for r in 1 2; do
    f "$out/$s.log" $r | cmp -s - /tmp/cal/$1-plain.out && echo "$s run$r identical" || echo "$s run$r DIFFERS"
  done
done
