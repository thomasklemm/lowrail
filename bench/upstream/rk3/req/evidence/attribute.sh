#!/usr/bin/env bash
# attribute.sh A B: per-function self Ir of Callgrind run B minus run A (reqrun.rb's /tmp/reqcg-PID.* dumps, the
# measured-window dump only), functions moving by more than 20,000 Ir.
ann() { callgrind_annotate --inclusive=no --threshold=100 $(ls /tmp/reqcg-$1.*.1) | grep -E '^ *[0-9][0-9,]* ' |
  awk '{n=$1; gsub(",","",n); sub(/^ *[0-9,]+ +(\([^)]*\) +)?/,""); print $0 "\t" n}' | sort; }
join -t$'\t' -a1 -a2 -e 0 -o '0,1.2,2.2' <(ann $1) <(ann $2) | awk -F'\t' '{d=$3-$2; if (d>20000||d< -20000) print d "\t" $1}' | sort -rn | head -12 | cut -c1-160
