#!/usr/bin/env bash
# MB1's benchmark-ips script on one pinned core, best of ROUNDS per tree, trees in a
# palindromic order rotated by round (main, branch, main again as A/A):
#   mb1_ips.sh OUT RUBY MAIN_TREE BRANCH_TREE [RUBY_FLAGS] [ROUNDS] [CPU]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$1 ruby=$2 main=$3 branch=$4 flags=${5:-} rounds=${6:-5} cpu=${7:-3}
ips=$(ls -d "$here"/../../../.lowrail/private/pmap/gems/gems/benchmark-ips-*/lib | tail -1)
for r in $(seq 1 "$rounds"); do
  if (( r % 2 )); then order=(main branch aa); else order=(aa branch main); fi
  for t in "${order[@]}"; do
    tree=$main; [ "$t" = branch ] && tree=$branch
    echo "### $t round $r" >> "$out"
    (cd /tmp && MB1_RAILS=$tree taskset -c "$cpu" "$ruby" $flags -I "$ips" "$here/mb1_ips.rb" 2>&1 | grep -E "i/s|^ruby ") >> "$out"
  done
done
"$ruby" -e '
  best = Hash.new { |h, k| h[k] = {} }
  tree = nil
  File.foreach(ARGV[0]) do |line|
    if line =~ /^### (\w+)/ then tree = $1
    elsif line =~ /^\s*(.+?)\s+([\d.]+)(k?) \(±/
      v = $2.to_f * ($3 == "k" ? 1000 : 1)
      best[$1][tree] = [best[$1][tree] || 0, v].max
    end
  end
  best.each do |name, t|
    printf("%-45s main %9.0f  A/A %+5.1f%%  branch %9.0f  %+5.1f%%\n", name, t["main"], 100 * (t["aa"] / t["main"] - 1),
      t["branch"], 100 * (t["branch"] / t["main"] - 1))
  end' "$out"
