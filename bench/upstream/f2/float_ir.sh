#!/bin/bash
# float_ir.sh RUBY OUT [CASE...]: Callgrind Ir per iteration of top-level loops with Float Hash keys and Float
# equality (F2). Whole process, (Ir at N - Ir at 0) / N, N = 1,000,000; fixed hash salt (fixseed.so, F1_SEED,
# default 1), no ASLR, fixed heap. RUBY is a ruby or miniruby binary. KEEP=1 keeps the Callgrind files for fnsum.sh.
export PATH=$HOME/w/valgrind-brk512/bin:$PATH LD_PRELOAD=$HOME/w/shim/fixseed.so F1_SEED=${F1_SEED:-1}
ruby=$1 out=$2; shift 2; mkdir -p $out
N=${N:-1000000}
if $ruby -e 'exit RUBY_VERSION >= "4.1"'; then export RUBY_GC_HEAP_INIT_BYTES=33554432
else export RUBY_GC_HEAP_0_INIT_SLOTS=838860 RUBY_GC_HEAP_1_INIT_SLOTS=419430 RUBY_GC_HEAP_2_INIT_SLOTS=209715 RUBY_GC_HEAP_3_INIT_SLOTS=104857 RUBY_GC_HEAP_4_INIT_SLOTS=52428; fi
H2='h = {1e300 => 1, 2e300 => 2}'
H100='h = (1..100).to_h { [_1 * 1e300, _1] }'
F2='h = {1.5 => 1, 2.5 => 2}'
F100='h = (1..100).to_h { [_1 * 0.5, _1] }'
declare -A C=(
  [empty]="$H2; i = 0; while i < @N; h; i += 1; end"
  [heap2_equal]="$H2; k = 1e300 * 1; i = 0; while i < @N; h[k]; i += 1; end"
  [heap2_same]="$H2; k = h.keys[0]; i = 0; while i < @N; h[k]; i += 1; end"
  [heap2_miss]="$H2; k = 3e300 * 1; i = 0; while i < @N; h[k]; i += 1; end"
  [heap2_review]="$H2; i = 0; while i < @N; h[1e300 * 1]; i += 1; end"
  [heap2_alloc]="$H2; i = 0; while i < @N; 1e300 * 1; i += 1; end"
  [heap100_equal]="$H100; k = 50 * 1e300; i = 0; while i < @N; h[k]; i += 1; end"
  [heap100_same]="$H100; k = h.keys[49]; i = 0; while i < @N; h[k]; i += 1; end"
  [heap100_miss]="$H100; k = 1e300 * 0.5; i = 0; while i < @N; h[k]; i += 1; end"
  [flo2_hit]="$F2; k = 3.0 / 2; i = 0; while i < @N; h[k]; i += 1; end"
  [flo2_miss]="$F2; k = 3.5; i = 0; while i < @N; h[k]; i += 1; end"
  [flo100_hit]="$F100; k = 25.0; i = 0; while i < @N; h[k]; i += 1; end"
  [flo100_miss]="$F100; k = 0.25; i = 0; while i < @N; h[k]; i += 1; end"
  [inf_equal]="h = {Float::INFINITY => 1, 0.5 => 2}; k = 1.0 / 0; i = 0; while i < @N; h[k]; i += 1; end"
  [negzero]="h = {0.0 => 1, 0.5 => 2}; k = -0.0; i = 0; while i < @N; h[k]; i += 1; end"
  [sym3]="h = {a: 1, b: 2, c: 3}; i = 0; while i < @N; h[:b]; i += 1; end"
  [str3_equal]="h = {'a' => 1, 'b' => 2, 'c' => 3}; k = +'b'; i = 0; while i < @N; h[k]; i += 1; end"
  [eq_heap]="a = 1e300 * 1; b = 1e300 * 1; i = 0; while i < @N; a == b; i += 1; end"
  [eq_heap_same]="a = Float::INFINITY; i = 0; while i < @N; a == Float::INFINITY; i += 1; end"
  [eq_flo_heap]="a = 0.5; b = Float::INFINITY; i = 0; while i < @N; a == b; i += 1; end"
  [eql_heap]="a = 1e300 * 1; b = 1e300 * 1; i = 0; while i < @N; a.eql?(b); i += 1; end"
  [eq_flo]="a = 1.5; b = 3.0 / 2; i = 0; while i < @N; a == b; i += 1; end"
  [include_heap]="a = [1e299, 2e299, 3e299]; k = 3e299 * 1; i = 0; while i < @N; a.include?(k); i += 1; end"
  [include_int]="a = [1, 2, 3]; i = 0; while i < @N; a.include?(4); i += 1; end"
  [include_sym]="a = [:a, :b, :c]; i = 0; while i < @N; a.include?(:d); i += 1; end"
  [include_flo]="a = [1.5, 2.5, 3.5]; i = 0; while i < @N; a.include?(4.5); i += 1; end"
)
cases=("$@"); [ ${#cases[@]} = 0 ] && cases=("${!C[@]}")
for c in "${cases[@]}"; do
  r=()
  for n in 0 $N; do
    f=$out/$c-$n.log
    cg=/dev/null; [ -n "$KEEP" ] && cg=$out/$c-$n.cg
    setarch -R valgrind --tool=callgrind --callgrind-out-file=$cg $ruby --disable-gems -e "${C[$c]//@N/$n}" > $f 2>&1
    grep -q "brk segment overflow" $f && echo "BRK $f"
    r+=($(awk '/Collected/ {print $4}' $f))
  done
  awk -v c=$c -v a=${r[0]} -v z=${r[1]} -v n=$N 'BEGIN { printf "%s %.0f\n", c, (z - a) / n }'
done | sort > $out/result.txt
cat $out/result.txt
