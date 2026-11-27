#!/usr/bin/env bash
# Callgrind Ir per call for price_micro.rb: each case x mode, N=0 and N=200000, two runs each (A/A).
#   price_run.sh OUT
# Modes: master YJIT, master ZJIT, headline6 ZJIT; ZJIT runs with --zjit-max-versions=2 so sym_final reaches its
# final version after one invalidation (the default 4 needs three).
set -uo pipefail
out=$1
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out"
Z="--zjit --zjit-max-versions=2"
job() { # CASE MODE RUN N
  local c=$1 m=$2 r=$3 n=$4 prefix flags
  case $m in
    yjit) prefix=master-0d399335b7 flags=--yjit ;;
    zjit) prefix=master-0d399335b7 flags=$Z ;;
    hzjit) prefix=h6-5c4239a16d flags=$Z ;;
  esac
  valgrind --tool=callgrind --toggle-collect=rb_ary_cycle --smc-check=all-non-file \
    --callgrind-out-file="$out/$c-$m-$r-$n.cg" "$HOME/rubies/$prefix/bin/ruby" $flags "$here/price_micro.rb" "$c" "$n" \
    > "$out/$c-$m-$r-$n.log" 2>&1
  echo "$c $m $r $n $(grep -m1 '^totals:' "$out/$c-$m-$r-$n.cg" | awk '{print $2}')" >> "$out/ir.txt"
}
export -f job
export out here Z
for c in super_block super_plain sym_first sym_final; do
  for m in yjit zjit hzjit; do for r in a b; do for n in 0 200000; do echo "$c $m $r $n"; done; done; done
done | xargs -P "${JOBS:-6}" -L1 bash -c 'job "$@"' _
