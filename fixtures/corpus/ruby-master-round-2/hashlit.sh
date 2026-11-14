#!/bin/bash
# hashlit.sh PREFIX... : Ir per Hash literal (1 and 3 pairs), whole-process Callgrind with the pinned tool,
# (Ir(n=200k) - Ir(n=0)) / 200k, GC disabled and enabled. Logs kept in ~/w/hl2 and checked for brk overflow.
export PATH=$HOME/w/vg319brk/bin:$PATH
mkdir -p ~/w/hl2
for p in "$@"; do
  for shape in "{a: v}" "{a: v, b: v, c: v}" "{}"; do
    for gc in "GC.disable;" ""; do
      r=()
      for n in 0 200000; do
        f=~/w/hl2/$(basename $p)-$(echo "$shape" | tr -dc 'a-z' | wc -c)-${gc:+nogc}-$n.log
        valgrind --tool=callgrind --callgrind-out-file=/dev/null $p/bin/ruby --disable-gems -e "def run(n, v); i = 0; x = nil; while i < n; x = $shape; i += 1; end; x; end; $gc run($n, 2)" > $f 2>&1
        grep -q "brk segment overflow" $f && echo "BRK $f"
        r+=($(awk '/Collected/ {print $4}' $f))
      done
      echo "$(basename $p) shape=[$shape] ${gc:-gc-on} Ir/literal=$(( (r[1] - r[0]) / 200000 ))"
    done
  done
done
