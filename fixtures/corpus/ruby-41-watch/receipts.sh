#!/bin/bash
# receipts.sh : trimmed receipts for docs/upstream/data/ruby-41-watch/receipts.tar.gz
set -euo pipefail
root=/home/user/workspace/repo
src=$root/.lowrail/private/ruby-41-watch
out=/tmp/w/receipts/ruby-41-watch
rm -rf /tmp/w/receipts && mkdir -p $out/runs
cd $src
for label in r407a r407b rmasa rmasb rfixa rfixb rfita rfitb cg407a cg407b cg407la cg407lb cgmasa cgmasb cgfixa cgfixb cgfita cglobm1 cglobf1 gc407a gc407b gcmasa gcmasb gcby407 gcbymas gcpoola gcpoolb; do
  [ -d $label ] || continue
  mkdir -p $out/runs/$label
  for f in $label/*.json; do
    # Allocation runs keep the top 50 sites per workload; GC and Callgrind runs keep no sites.
    keep=50; case $label in gc*|cg*) keep=0 ;; esac
    mise exec ruby@4.0.7 -- ruby -rjson -e 'j = JSON.parse(File.read(ARGV[0])); j["workloads"].each { _1["sites"] = _1["sites"].first(Integer(ARGV[2])) }; File.write(ARGV[1], JSON.generate(j))' $f $out/runs/$f $keep
  done
done
# Callgrind totals only (the dumps themselves stay private).
for d in /tmp/w/cgdumps/*; do
  [ -d $d ] || continue
  for f in $d/*.cg.[0-9]*; do echo "$(basename $d)/$(basename $f) $(grep -m1 '^totals:' $f)"; done
done > $out/callgrind-totals.txt
cp /tmp/w/receipt-*.txt /tmp/w/receipt-*.json $out/ 2>/dev/null || true
tar -C /tmp/w/receipts -czf $root/docs/upstream/data/ruby-41-watch/receipts.tar.gz ruby-41-watch
ls -la $root/docs/upstream/data/ruby-41-watch/receipts.tar.gz
