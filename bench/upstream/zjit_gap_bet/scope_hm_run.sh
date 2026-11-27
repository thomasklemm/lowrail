#!/usr/bin/env bash
# scope_hm (cpu_open.rb), Rails main by path in ~/w/rails-main (micro.Gemfile), on Rails main 2e299253f9 (with rails#59569): ns per call, interleaved rounds,
# master YJIT x2, master ZJIT x2, headline6 ZJIT x1, pinned to CPU ${CPU:-3}. Then one --zjit-stats run per ZJIT build.
#   run.sh OUT ROUNDS CASE
set -uo pipefail
out=$1 rounds=$2 case=${3:-scope_hm}
here=$(cd "$(dirname "$0")" && pwd)
script=$HOME/workspace/repo/bench/upstream/rails-open/cpu_open.rb
Z="--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024"
mkdir -p "$out"
export BUNDLE_GEMFILE=$here/micro.Gemfile WARMUP=${WARMUP:-20000}
one() { # LABEL PREFIX FLAGS...
  local label=$1 prefix=$2; shift 2
  echo "$label $(taskset -c "${CPU:-3}" "$HOME/rubies/$prefix/bin/ruby" "$@" "$script" "$case" "${N:-200000}" ns)" >> "$out/$case-ns.txt"
}
for r in $(seq 1 "$rounds"); do
  one yjit-a master-0d399335b7 --yjit
  one zjit-a master-0d399335b7 $Z
  one hzjit h6-5c4239a16d $Z
  one zjit-b master-0d399335b7 $Z
  one yjit-b master-0d399335b7 --yjit
done
for p in master-0d399335b7 h6-5c4239a16d; do
  "$HOME/rubies/$p/bin/ruby" $Z --zjit-stats-quiet -e 'f = ARGV.shift; at_exit { s = RubyVM::ZJIT.stats; File.write(f, s.to_a.select { _2.is_a?(Integer) && _2 > 0 }.map { "#{_1}\t#{_2}" }.join("\n") + "\n") }; load ARGV.shift' \
    "$out/$case-$p-stats.tsv" "$script" "$case" "${N:-200000}" ns > /dev/null
done
