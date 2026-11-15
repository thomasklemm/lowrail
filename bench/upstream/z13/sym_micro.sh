#!/bin/bash
# run.sh OUTDIR: sym_micro.rb under Callgrind in interp/YJIT/ZJIT (and an A/A of each JIT) on ~/w/rm.
out=$1; mkdir -p $out; cd $(dirname $0)
export PATH=$HOME/w/vg319brk/bin:$PATH
for m in interp yjit zjit yjit2 zjit2; do
  case $m in interp) f=();; yjit*) f=(--yjit);; zjit*) f=(--zjit);; esac
  OUT=$out/$m.names valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=$out/$m.cg.%p $HOME/w/rm/bin/ruby -I $HOME/w/cgext "${f[@]}" sym_micro.rb > $out/$m.log 2>&1
done
for m in interp yjit zjit yjit2 zjit2; do
  base=$(grep -h "^summary:\|^totals:" $(ls $out/$m.cg.*.1) | head -1 | awk '{print $2}')
  i=2; while read name; do
    f=$(ls $out/$m.cg.*.$i); v=$(grep -h "^summary:\|^totals:" $f | head -1 | awk '{print $2}')
    echo "$m|$name|$(( (v - base) / 1000 ))"; i=$((i+1))
  done < $out/$m.names
done
