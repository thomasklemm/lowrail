#!/usr/bin/env bash
# Round 3 of docs/upstream/combined-effect.md on Ruby master, two axes:
#   Rails axis: Rails main against Rails main with our merged PRs reverted, both on Ruby master.
#   Ruby axis:  Ruby master against Ruby master with our merged ruby/ruby commits reverted, both on Rails main.
#   bench/upstream/combined_r3/run_master.sh RAILS_REPO MAIN_SHA REVERTED_SHA APPS RUBY_MAIN_BIN RUBY_WITHOUT_BIN \
#     RUBY_BENCH_DIR VALGRIND OUT
# Census allocations (interp, zjit; 200 warmups as in zjit_combined/census_abba.sh) in the order
# r3zw, r3zwo, r3zwo2, r3zw2 (Rails axis, ABBA), then r3rwo, r3rwo2, r3zw3 (Ruby axis: r3zw2, r3rwo, r3rwo2, r3zw3).
# Then ruby-bench objects per iteration under ZJIT and instructions per iteration under ZJIT with the fixed heap.
set -uo pipefail
repo=$1 main=$2 reverted=$3 apps=$4 rmain=$5 rwithout=$6 rb=$7 valgrind=$8 out=$9
cd "$(dirname "$0")/../../.."
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
export CENSUS_WARMUP=${CENSUS_WARMUP:-200}
census() { mise exec ruby@4.0.9 -- script/census run --label "$1" --ruby "$2" --rails "$repo@$3" --apps "$apps" --modes interp,zjit --jobs 2; }
if [[ -z ${SKIP_CENSUS:-} ]]; then
  step census r3zw "$rmain" "$main"; step census r3zwo "$rmain" "$reverted"; step census r3zwo2 "$rmain" "$reverted"
  step census r3zw2 "$rmain" "$main"; step census r3rwo "$rwithout" "$main"; step census r3rwo2 "$rwithout" "$main"
  step census r3zw3 "$rmain" "$main"
fi
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
mkdir -p "$out/alloc" "$out/ir"
cp bench/upstream/merged_sum/sumalloc.rb "$rb/harness/sumalloc.rb"
# label  ruby       Gemfile variant
runs=("main-a $rmain main-a" "without-a $rmain without-a" "without-b $rmain without-b" "main-b $rmain main-b"
      "rwo-a $rwithout main-a" "rwo-b $rwithout main-b" "main-c $rmain main-a")
for b in railsbench lobsters shipit; do
  for r in "${runs[@]}"; do
    set -- $r
    f="$out/alloc/$b-zjit-$1.json"
    [[ -e $f ]] && continue
    echo "== alloc $b zjit $1 $(date -u +%T)"
    (cd "$rb" && env PATH="$2:$PATH" BUNDLE_GEMFILE="$rb/benchmarks/$b/Gemfile.$3" HARNESS=sumalloc SUM_OUT="$f" \
      "$2/ruby" --zjit "benchmarks/$b/benchmark.rb") > "$out/alloc/$b-zjit-$1.log" 2>&1
  done
done
ir() { RUBY_BENCH_DIR=$rb step mise exec ruby@4.0.9 -- ruby bench/upstream/actionview_cpu/ruby_bench_ir.rb run --out "$out/ir/$1" \
  --valgrind "$valgrind" --ruby "$2/ruby" --benches railsbench,lobsters,shipit --modes zjit --jobs 2 --tag "$1" "${@:3}"; }
ir zm "$rmain" main-a main-b without-a
ir zr "$rwithout" main-a
echo "ALL DONE $(date -u +%T)"
