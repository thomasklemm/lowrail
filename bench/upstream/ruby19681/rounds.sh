#!/usr/bin/env bash
# RUBY19681 real-workload round: ruby-bench run_benchmarks.rb, master / A/A (same master binary) / PR head
# rebased onto that master, plain --zjit; run_benchmarks.rb --zjit-stats adds compile_time_ns and compile_lir_time_ns columns.
#   rounds.sh OUT_DIR FIRST LAST
# Each round is one run_benchmarks.rb invocation per benchmark with --interleave over the three
# executables; their order rotates per round so no executable always runs first.
# RB: ruby-bench checkout (default ~/w/rb). Builds in ~/rb/master and ~/rb/head.
set -euo pipefail
out=$1 first=$2 last=$3
rb=${RB:-$HOME/w/rb}
mkdir -p "$out"; out=$(cd "$out" && pwd)
m="$HOME/rb/master/bin/ruby --zjit"
h="$HOME/rb/head/bin/ruby --zjit"
for r in $(seq "$first" "$last"); do
  case $((r % 3)) in
    0) exes=(-e "master::$m" -e "aa::$m" -e "head::$h") ;;
    1) exes=(-e "head::$h" -e "master::$m" -e "aa::$m") ;;
    2) exes=(-e "aa::$m" -e "head::$h" -e "master::$m") ;;
  esac
  for bench in ${BENCHES:-railsbench lobsters shipit}; do
    [ -f "$out/$bench-r$r.json" ] && continue
    (cd "$rb" && unset RUBYOPT && "${LAUNCHER:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}" run_benchmarks.rb "${exes[@]}" --interleave --turbo --no-sudo \
      --zjit-stats=compile_time_ns,compile_lir_time_ns --out_path="$out" --out-name="$bench-r$r" "$bench") \
      > "$out/$bench-r$r.log" 2>&1
    mv "$rb/$bench-r$r".{json,txt,csv} "$out/"  # --out-name ignores --out_path
    echo "$(date +%T) round $r $bench done"
  done
done
