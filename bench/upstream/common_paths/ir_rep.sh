#!/bin/bash
# ir_rep.sh OUTDIR "case:cand ..." "MODES" REPS
out=$1; mkdir -p $out; specs=$2; modes=$3; reps=${4:-1}; N=${N:-3000}
jobs=$out/jobs.txt; : > $jobs
for s in $specs; do c=${s%%:*}; cand=${s#*:}; for m in $modes; do for r in $(seq 1 $reps); do for v in main:main aa:aa cand:$cand; do for n in 0 $N; do
  echo "$c ${v%%:*}$r ${v#*:} $m $n" >> $jobs; done; done; done; done; done
one() {
  c=$1 v=$2 d=$3 m=$4 n=$5
  case $m in
    i49) P=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; f="" ;;
    y49) P=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; f="--yjit" ;;
    i41) P=$HOME/work/ruby-master/bin; f="" ;;
    z41) P=$HOME/work/ruby-master/bin; f="--zjit" ;;
  esac
  G=$HOME/work/wt/$d/Gemfile; case $m in i41|z41) G=$HOME/work/gemfiles/$d/Gemfile ;; esac
  smc=""; [ -n "$f" ] && smc="--smc-check=all"
  cd $HOME/work/wt/$d && BUNDLE_GEMFILE=$G PATH=$P:$PATH valgrind --tool=callgrind --collect-atstart=no \
    --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null ruby $f $HOME/work/bench/micro.rb $c $n ir \
    > $out/$c-$v-$m-$n.out 2>&1
}
export -f one; export out
xargs -P 8 -L 1 bash -c 'one "$@"' _ < $jobs
echo IRDONE
