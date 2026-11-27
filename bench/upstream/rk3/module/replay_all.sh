#!/usr/bin/env bash
# replay_all.sh: replay.rb on base (e26338b40a) and head per Ruby and mode, then compare.rb.
here=$(cd "$(dirname "$0")" && pwd); out=$here/replay; mkdir -p $out
for v in ${RUBIES:-2.7.3 3.0.7 3.1.7 3.2.9 3.3.9 3.4.6 4.0.9}; do
  if [ -d /opt/hostedtoolcache/Ruby/$v ]; then r=/opt/hostedtoolcache/Ruby/$v/x64/bin/ruby; else r=$HOME/.local/share/mise/installs/ruby/$v/bin/ruby; fi
  for mode in clean util pure; do
    case $mode in
      clean) pre=() ;;
      util) pre=(-rcgi/util) ;;
      pure) case $v in 3.4*) pre=(-r "/home/user/workspace/repo/bench/upstream/rk3/pure_cgi.rb") ;;
                       4.0*) pre=(-rrbconfig -e '$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so"); load ARGV.shift') ;;
                       *) continue ;; esac ;;
    esac
    for t in base head; do
      lib=/home/user/workspace/repos/rack-rec/lib; [ $t = head ] && lib=/home/user/workspace/repos/rack/lib
      $r -W0 "${pre[@]}" -I $lib $here/replay.rb $here/suite-inputs.rec > $out/$t-$v-$mode.txt 2> $out/$t-$v-$mode.err
    done
    echo "$v $mode: $(tail -1 $out/head-$v-$mode.err) | $($r $here/compare.rb $out/base-$v-$mode.txt $out/head-$v-$mode.txt | tr '\n' ' ' | cut -c1-260)"
  done
done
