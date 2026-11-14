#!/bin/bash
# repro_ir.sh PREFIX OUT: Callgrind Ir per iteration of the PR body's three-line loops, as written (top level),
# whole process, (Ir at N = 2,000,000 - Ir at N = 0) / N; fixed hash salt (fixseed.so), no ASLR, fixed heap.
export PATH=$HOME/w/valgrind-brk512/bin:$PATH LD_PRELOAD=$HOME/w/shim/fixseed.so F1_SEED=1
pre=$1 out=$2; mkdir -p $out
if $pre/bin/ruby -e 'exit RUBY_VERSION >= "4.1"'; then export RUBY_GC_HEAP_INIT_BYTES=33554432
else export RUBY_GC_HEAP_0_INIT_SLOTS=838860 RUBY_GC_HEAP_1_INIT_SLOTS=419430 RUBY_GC_HEAP_2_INIT_SLOTS=209715 RUBY_GC_HEAP_3_INIT_SLOTS=104857 RUBY_GC_HEAP_4_INIT_SLOTS=52428; fi
declare -A C=(
  [h_b]='h = {a: 1, b: 2, c: 3}; i = 0; while i < N; h[:b]; i += 1; end'
  [ar_first]='h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}; i = 0; while i < N; h[:a]; i += 1; end'
  [ar_last]='h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}; i = 0; while i < N; h[:h]; i += 1; end'
  [ar_miss]='h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}; i = 0; while i < N; h[:_]; i += 1; end'
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
  echo "$c $(( (r[1] - r[0]) / 2000000 ))"
done | sort > $out/result.txt
cat $out/result.txt
