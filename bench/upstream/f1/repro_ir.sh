#!/bin/bash
# repro_ir.sh PREFIX OUT: Callgrind Ir per iteration of the PR body's three-line loops, as written (top level),
# 8-key rows use :k1..:k8, not hash_ar_aref.yml's :a..:h, whose :g and :h share a hint on the 4.0.9 build;
# whole process, (Ir at N = 2,000,000 - Ir at N = 0) / N; fixed hash salt (fixseed.so, F1_SEED, default 1), no ASLR, fixed heap.
export PATH=$HOME/w/valgrind-brk512/bin:$PATH LD_PRELOAD=$HOME/w/shim/fixseed.so F1_SEED=${F1_SEED:-1}
pre=$1 out=$2; mkdir -p $out
if $pre/bin/ruby -e 'exit RUBY_VERSION >= "4.1"'; then export RUBY_GC_HEAP_INIT_BYTES=33554432
else export RUBY_GC_HEAP_0_INIT_SLOTS=838860 RUBY_GC_HEAP_1_INIT_SLOTS=419430 RUBY_GC_HEAP_2_INIT_SLOTS=209715 RUBY_GC_HEAP_3_INIT_SLOTS=104857 RUBY_GC_HEAP_4_INIT_SLOTS=52428; fi
declare -A C=(
  [h_b]='h = {a: 1, b: 2, c: 3}; i = 0; while i < N; h[:b]; i += 1; end'
  [ar_first]='h = {k1:1, k2:2, k3:3, k4:4, k5:5, k6:6, k7:7, k8:8}; i = 0; while i < N; h[:k1]; i += 1; end'
  [ar_last]='h = {k1:1, k2:2, k3:3, k4:4, k5:5, k6:6, k7:7, k8:8}; i = 0; while i < N; h[:k8]; i += 1; end'
  [ar_miss]='h = {k1:1, k2:2, k3:3, k4:4, k5:5, k6:6, k7:7, k8:8}; i = 0; while i < N; h[:k9]; i += 1; end'
  [str_equal]='h = {"a" => 1, "b" => 2, "c" => 3}; k = +"b"; i = 0; while i < N; h[k]; i += 1; end'
  [empty]='h = {a: 1, b: 2, c: 3}; i = 0; while i < N; h; i += 1; end'
)
for c in "${!C[@]}"; do
  r=()
  for n in 0 2000000; do
    f=$out/$c-$n.log
    setarch -R valgrind --tool=callgrind --callgrind-out-file=/dev/null $pre/bin/ruby --disable-gems -e "${C[$c]//N/$n}" > $f 2>&1
    grep -q "brk segment overflow" $f && echo "BRK $f"
    r+=($(awk '/Collected/ {print $4}' $f))
  done
  awk -v c=$c -v a=${r[0]} -v z=${r[1]} 'BEGIN { printf "%s %.0f\n", c, (z - a) / 2000000 }'
done | sort > $out/result.txt
cat $out/result.txt
