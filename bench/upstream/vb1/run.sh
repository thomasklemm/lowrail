#!/bin/bash
# run.sh OUT TREE WIDTH|req MODE [CASE...]: one attr_bench.rb (WIDTH) or req_bench.rb (req) process under Callgrind
# with the census fixed heap. TREE is a Rails worktree under ~/vb1 with bundles in ~/vb1/suite-TREE (Ruby 4.0.9) and
# ~/vb1/suiteM-TREE (Ruby master). MODE: interp or yjit (4.0.9), minterp or zjit (Ruby master in ~/w/ruby-master).
# Writes OUT/TREE-MODE-wWIDTH.RUN.jsonl (RUN defaults to a) with Ir per call: (window Ir - _empty window Ir) / N.
set -euo pipefail
out=$1; tree=$2; width=$3; mode=$4; shift 4
run=${RUN:-a}
here=$(cd "$(dirname "$0")" && pwd)
case $mode in
  interp|yjit) bin=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; suite=suite; gems=gems409; ext=ext409 ;;
  minterp|zjit) bin=$HOME/w/ruby-master/bin; suite=suiteM; gems=gemsM; ext=extM ;;
esac
flag=""; smc=""
[ "$mode" = yjit ] && { flag="--yjit"; smc="--smc-check=all"; }
[ "$mode" = zjit ] && { flag="--zjit"; smc="--smc-check=all"; }
script=attr_bench.rb; [ "$width" = req ] && script=req_bench.rb
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
dir=$(mktemp -d)
mkdir -p "$out"
RAILS=$HOME/vb1/$tree BUNDLE_GEMFILE=$HOME/vb1/$suite-$tree/Gemfile BUNDLE_PATH=$HOME/vb1/$gems \
  IRWIN_DIR=$HOME/vb1/$ext WIDTH=$width PATH=$bin:$PATH \
  $HOME/vb1/vg/bin/valgrind --tool=callgrind --instr-atstart=no $smc --callgrind-out-file="$dir/cg.%p" \
  ruby $flag "$here/$script" "$@" > "$dir/stdout" 2> "$dir/stderr" || { tail -5 "$dir/stderr"; exit 1; }
grep -q "brk segment overflow" "$dir/stderr" && echo "BRK $tree $mode $width"
$bin/ruby -rjson -e '
  dir, tree, mode = ARGV
  ir = {}
  Dir["#{dir}/cg.*.*"].each do |f|
    text = File.read(f)
    name = text[/^desc: Trigger: Client Request: (.*)$/, 1] or next
    ir[name] = Integer(text[/^(?:totals|summary): (\d+)/, 1])
  end
  rows = File.readlines("#{dir}/stdout").map { JSON.parse(_1) }
  empty = ir.fetch("_empty").fdiv(rows.first["n"])
  rows.each do |r|
    r["ir"] = (ir.fetch(r["case"]).fdiv(r["n"]) - empty).round
    puts JSON.generate(r.merge("tree" => tree, "mode" => mode))
  end
' "$dir" "$tree" "$mode" > "$out/$tree-$mode-w$width.$run.jsonl"
rm -rf "$dir"
