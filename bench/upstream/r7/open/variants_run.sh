# Ir per call of Symbol-key variants. Copy key_variants.rb / key_calls.rb to /tmp/w/r7o/var/, then
# S=key_variants.rb VS="to_s eqq isa case" bash variants_run.sh  (modes i49 i41 z41; add y49 as needed)
# S=key_calls.rb VS="to_s name eqq nil" bash variants_run.sh
one() { v=$1 m=$2 n=$3
  case $m in i49) P=/home/user/.local/share/mise/installs/ruby/4.0.9/bin f="";; y49) P=/home/user/.local/share/mise/installs/ruby/4.0.9/bin f=--yjit;;
    i41) P=/home/user/.rubies/ruby-master-9aa0898240/bin f="";; z41) P=/home/user/.rubies/ruby-master-9aa0898240/bin f=--zjit;; esac
  smc=""; [ -n "$f" ] && smc="--smc-check=all"
  PATH=$P:$PATH valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null ruby $f /tmp/w/r7o/var/$S $v $n 2>&1 | grep -o 'Collected : [0-9]*' | sed "s/^/$v $m $n /"
}
export -f one
for v in $VS; do for m in i49 i41 z41; do for n in 0 5000; do echo "$v $m $n"; done; done; done | xargs -P 8 -L 1 bash -c 'one "$@"' _ > /tmp/w/r7o/var/out.txt
echo VDONE
