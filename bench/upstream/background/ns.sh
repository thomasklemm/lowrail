#!/bin/bash
# ns.sh (copy of census8/ns.sh for background/micro.rb) OUT BASE CAND "CASES" "MODES" [ROUNDS]: wall ns per call of micro.rb CASE, one process per run, pinned to
# one CPU. Each round runs every case and mode for main, aa (BASE again) and cand in a rotating order, so the
# variants interleave. MODES from interp yjit (Ruby 4.0.9). Report the best (minimum) of the rounds per variant.
out=$1 base=$2 cand=$3 cases=$4 modes=$5 rounds=${6:-7}
here=$(cd "$(dirname "$0")" && pwd)
bin=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}
cpu=${CPU:-3} n=${N:-200000}
order=("main:$base aa:$base cand:$cand" "aa:$base cand:$cand main:$base" "cand:$cand main:$base aa:$base")
for r in $(seq 1 "$rounds"); do
  for c in $cases; do for m in $modes; do
    flag=""; [ "$m" = yjit ] && flag="--yjit"
    for v in ${order[$(( (r - 1) % 3 ))]}; do
      ns=$(RAILS=${v#*:} PATH=$bin:$PATH taskset -c "$cpu" ruby $flag "$here/micro.rb" "$c" "$n" ns)
      echo "$r ${v%%:*} $c $m $ns" >> "$out"
    done
  done; done
done
