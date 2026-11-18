#!/usr/bin/env bash
# Round 3 of docs/upstream/combined-effect.md, Ruby 4.0.9 (interpreter and YJIT):
# Rails main against the same commit with our merged PRs reverted.
#   bench/upstream/combined_r3/run_409.sh RAILS_REPO MAIN_SHA REVERTED_SHA APPS RUBY_BENCH_DIR VALGRIND OUT
# 1. census allocations in ABBA order (r3w, r3wo, r3wo2, r3w2), as in combined_effect/census_abba.sh;
# 2. ruby-bench objects and GC runs per iteration (merged_sum/sumalloc.rb), two processes per tree;
# 3. ruby-bench instructions per iteration (actionview_cpu/ruby_bench_ir.rb), main-a, main-b, without-a.
# ruby-bench runs use the fixed heap from docs/bench.md. Each benchmark has Gemfile.main-a/-b
# (Rails at MAIN_SHA) and Gemfile.without-a/-b (Rails at REVERTED_SHA).
set -uo pipefail
repo=$1 main=$2 reverted=$3 apps=$4 rb=$5 valgrind=$6 out=$7
cd "$(dirname "$0")/../../.."
root=$PWD
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
census() { mise exec ruby@4.0.9 -- script/census run --label "$1" --rails "$repo@$2" --apps "$apps" --modes interp,yjit --jobs 2; }
if [[ -z ${SKIP_CENSUS:-} ]]; then
  step census r3w "$main"; step census r3wo "$reverted"; step census r3wo2 "$reverted"; step census r3w2 "$main"
fi
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
ruby=$(mise where ruby@4.0.9)/bin/ruby
mkdir -p "$out/alloc" "$out/ir"
cp bench/upstream/merged_sum/sumalloc.rb "$rb/harness/sumalloc.rb"
for b in railsbench lobsters shipit; do
  for m in interp yjit; do
    for v in main-a without-a without-b main-b; do
      f="$out/alloc/$b-$m-$v.json"
      [[ -e $f ]] && continue
      echo "== alloc $b $m $v $(date -u +%T)"
      (cd "$rb" && env BUNDLE_GEMFILE="$rb/benchmarks/$b/Gemfile.$v" HARNESS=sumalloc SUM_OUT="$f" \
        "$ruby" $([[ $m == yjit ]] && echo --yjit) "benchmarks/$b/benchmark.rb") > "$out/alloc/$b-$m-$v.log" 2>&1
    done
  done
done
RUBY_BENCH_DIR=$rb step mise exec ruby@4.0.9 -- ruby bench/upstream/actionview_cpu/ruby_bench_ir.rb run --out "$out/ir" \
  --valgrind "$valgrind" --ruby "$ruby" --benches railsbench,lobsters,shipit --modes interpreter,yjit --jobs 2 --tag r3 \
  main-a main-b without-a
echo "ALL DONE $(date -u +%T)"
