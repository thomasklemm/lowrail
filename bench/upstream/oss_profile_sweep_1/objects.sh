#!/usr/bin/env bash
# objects.sh OUT BASE_TREE CANDIDATE_TREE GEM BENCH.rb [RUBY]
#
# Objects per call only, from script/upstream-bench's own worker (3,000 warm-up calls, GC off, windows of 1,000
# and 2,000 calls), with bench.md's heap floors, base, candidate and base again, per mode. Used where a call is
# too slow for the Callgrind cells (a 3,000-call warm-up under Valgrind takes hours): no instruction or time claim.
set -euo pipefail
out=$1 base=$2 candidate=$3 gem=$4 bench=$5 ruby=${6:-4.0.9}
root=$(cd "$(dirname "$0")/../../.." && pwd)
[ ! -e "$out" ] || { echo "$out exists" >&2; exit 1; }
mkdir -p "$out/raw"
cp "$bench" "$out/"
bin=$(mise where "ruby@$ruby")/bin
heap=(RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000)
for side in base candidate; do
  tree=${!side}
  mkdir -p "$out/$side"
  printf 'source "https://rubygems.org"\ngem "%s", path: "%s"\n' "$gem" "$tree" > "$out/$side/Gemfile"
  (cd "$out/$side" && PATH="$bin:$PATH" BUNDLE_GEMFILE="$out/$side/Gemfile" bundle lock --local > /dev/null)
  git -C "$tree" rev-parse HEAD > "$out/$side/head.txt"
done
: > "$out/commands.sh"
for mode in interp yjit; do
  flag=(); [ "$mode" = yjit ] && flag=(--yjit)
  for side in base candidate base2; do
    gemfile_side=${side%2}
    cmd=(env -u RUBYOPT "${heap[@]}" BUNDLE_GEMFILE="$out/$gemfile_side/Gemfile" "$bin/ruby" "${flag[@]}" -rbundler/setup
      "$root/script/upstream-bench" --worker objects "$bench")
    printf '%q ' "${cmd[@]}" >> "$out/commands.sh"; echo >> "$out/commands.sh"
    "${cmd[@]}" > "$out/raw/$mode-$side.txt"
  done
done
"$bin/ruby" -e 'puts RUBY_DESCRIPTION' > "$out/ruby.txt"
{
  echo "| Mode | Case | Base | Candidate | Base again | Change |"
  echo "| --- | --- | ---: | ---: | ---: | ---: |"
  for mode in interp yjit; do
    paste "$out/raw/$mode-base.txt" "$out/raw/$mode-candidate.txt" "$out/raw/$mode-base2.txt" |
      awk -F'\t' -v m="$mode" '{ name = $1; sub(/^objects /, "", name); b = $2; c = $4; b2 = $6
        aa = (b == b2) ? "" : " (A/A differs)"; printf "| %s | %s | %s | %s | %s | %+.1f%%%s |\n", m, name, b, c, b2, 100 * (c - b) / b, aa }'
  done
} > "$out/table.md"
cat "$out/table.md"
