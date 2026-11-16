#!/bin/bash
# Objects per call on main and the change per candidate, one column each: sweep_table.sh <rails checkout> [candidates...]
# Run with the checkout's bundle (BUNDLE_GEMFILE or from inside it). Output files go to a temporary directory.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rails="$(cd "$1" && pwd)"; shift
cands=("${@:-O PH AMT B C D V SV CB HFT LT CBT ST OS LB TR DA T2 TB A AM all}")
read -r -a cands <<< "${cands[*]}"
out="$(mktemp -d)"
cd "$rails"
bundle exec ruby "$here/sweep_count.rb" . > "$out/main.txt"
for p in "${cands[@]}"; do PATCH=$p bundle exec ruby "$here/sweep_count.rb" . > "$out/$p.txt" & done
wait
ruby -e '
dir, *ps = ARGV
read = ->(f) { File.readlines(File.join(dir, "#{f}.txt")).to_h { |l| [l[0, 28].strip, l[28..].to_f] } }
main = read.("main"); d = ps.to_h { |p| [p, read.(p)] }
puts "| Objects per call | main | #{ps.join(" | ")} |", "| --- | ---: |#{" ---: |" * ps.size}"
main.each { |k, v| puts "| `#{k}` | #{v.round} | #{ps.map { |p| x = (d[p][k] - v).round; x.zero? ? "" : x }.join(" | ")} |" }
' "$out" "${cands[@]}"
