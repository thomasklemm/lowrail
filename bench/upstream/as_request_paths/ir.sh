#!/bin/bash
# ir.sh OUTDIR "case:cand ..." "MODES" REPS  -> OUTDIR/<case>-<variant><rep>-<mode>-<n>.out
# Variants: main and aa (Rails main twice, the A/A) and the candidate worktree, all under ~/w/wt.
# Modes: i49/y49 = Ruby 4.0.9 interpreter/YJIT, i41/z41 = Ruby master 9aa0898240 interpreter/ZJIT.
out=$1; mkdir -p $out; specs=$2; modes=$3; reps=${4:-1}; N=${N:-3000}
jobs=$out/jobs.txt; : > $jobs
for s in $specs; do c=${s%%:*}; cand=${s#*:}; for m in $modes; do for r in $(seq 1 $reps); do for v in main:main aa:aa cand:$cand; do for n in 0 $N; do
  echo "$c ${v%%:*}$r ${v#*:} $m $n" >> $jobs; done; done; done; done; done
one() {
  c=$1 v=$2 d=$3 m=$4 n=$5
  case $m in
    i49) R=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby; f="" ;;
    y49) R=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby; f="--yjit" ;;
    i41) R=$HOME/w/ruby-master/bin/ruby; f="" ;;
    z41) R=$HOME/w/ruby-master/bin/ruby; f="--zjit" ;;
  esac
  smc=""; [ -n "$f" ] && smc="--smc-check=all"
  RAILS=$HOME/w/wt/$d valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc \
    --callgrind-out-file=/dev/null $R $f $PWD/${MICRO:-micro.rb} $c $n ir > $out/$c-$v-$m-$n.out 2>&1
}
export -f one; export out MICRO
cd $(dirname $0) && xargs -P ${JOBS:-8} -L 1 bash -c 'one "$@"' _ < $jobs
echo IRDONE
