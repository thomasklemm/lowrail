#!/bin/bash
# cg_l3.sh: bench/upstream/l3/attr_bench.rb under stock Callgrind (IrWin windows), interpreter, 30 columns, core 1.
set -u
B=/home/user/workspace/repo/bench/upstream/l3/attr_bench.rb
R=$HOME/.local/share/mise/installs/ruby/4.0.9/bin
export PATH=$R:$PATH BUNDLE_PATH=$HOME/ips/gems IRWIN_DIR=$HOME/ips/ext WIDTH=30
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
out=/tmp/cg_l3; mkdir -p $out
for t in main l3 l3b l3h main2; do
  d=$(mktemp -d)
  RAILS=$HOME/ips/$t BUNDLE_GEMFILE=$HOME/ips/b-$t/Gemfile taskset -c 1 valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file="$d/cg.%p" \
    ruby $B marshal_dump attributes_for_database attributes_before_type_cast > $d/stdout 2> $d/stderr
  ruby -rjson -e '
    dir, tree = ARGV
    ir = {}
    Dir["#{dir}/cg.*.*"].each { |f| t = File.read(f); n = t[/^desc: Trigger: Client Request: (.*)$/, 1] or next; ir[n] = Integer(t[/^(?:totals|summary): (\d+)/, 1]) }
    rows = File.readlines("#{dir}/stdout").map { JSON.parse(_1) }
    empty = ir.fetch("_empty").fdiv(rows.first["n"])
    rows.each { |r| next if r["case"] == "_empty"; printf("%-6s %-28s %10d %6.2f\n", tree, r["case"], (ir.fetch(r["case"]).fdiv(r["n"]) - empty).round, r["objects"]) }
  ' $d $t >> $out/ir.txt 2>> $out/err.txt || tail -3 $d/stderr >> $out/err.txt
  rm -rf $d
done
echo done >> $out/ir.txt
