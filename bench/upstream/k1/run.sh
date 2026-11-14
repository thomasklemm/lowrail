#!/bin/bash
# run.sh OUT TREE WIDTH MODE [CASE...]: one attr_bench.rb process under Callgrind, with the census fixed heap.
# TREE is a Rails checkout under ~/k1 with a bundle in ~/k1/suite-TREE. Writes OUT/TREE-MODE-wWIDTH.jsonl with
# Ir per call (window Ir / N, minus the _empty window's per-call Ir), objects per call and JIT blocks.
set -euo pipefail
out=$1; tree=$2; width=$3; mode=$4; shift 4
here=$(cd "$(dirname "$0")" && pwd)
bin=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}
flag=""; smc=""
[ "$mode" = yjit ] && { flag="--yjit"; smc="--smc-check=all"; }
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
dir=$(mktemp -d)
mkdir -p "$out"
RAILS=$HOME/k1/$tree BUNDLE_GEMFILE=$HOME/k1/suite-$tree/Gemfile WIDTH=$width PATH=$bin:$PATH \
  valgrind --tool=callgrind --instr-atstart=no $smc --callgrind-out-file="$dir/cg.%p" \
  ruby $flag "$here/attr_bench.rb" "$@" > "$dir/stdout" 2> "$dir/stderr" || { tail -5 "$dir/stderr"; exit 1; }
ruby -rjson -e '
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
' "$dir" "$tree" "$mode" > "$out/$tree-$mode-w$width.jsonl"
rm -rf "$dir"
