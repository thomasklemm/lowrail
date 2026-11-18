#!/usr/bin/env bash
# diff_all.sh RACK OUTDIR: both differentials and review_exactness.rb under rack's CI bundle on each installed Ruby,
# plain and with cgi/util preloaded, plus the pure-Ruby CGI fallback on 3.4 and 4.0.
here=$(cd "$(dirname "$0")" && pwd); rack=$1; out=$2; mkdir -p "$out"; cd "$rack"
for v in ${RUBIES:-4.0.9 3.4.12 3.3.10 3.2.9}; do
  export PATH=$HOME/.local/share/mise/installs/ruby/$v/bin:$PATH
  bundle install --quiet >/dev/null 2>&1
  for mode in clean util pure; do
    case $mode in
      clean) pre=() ;;
      util) pre=(-rcgi/util) ;;
      pure) case $v in 3.4*) pre=(-r "$here/pure_cgi.rb") ;; 4.0*) pre=(-rrbconfig -e '$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so")') ;; *) continue ;; esac ;;
    esac
    for s in diff_unescape diff_escape review_exactness; do
      if [ "$mode" = pure ] && [ "$v" = 4.0.9 ]; then
        CI=spec bundle exec ruby -rrbconfig -I lib -e '$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so"); load ARGV.shift' "$here/$s.rb" > "$out/$s-$v-$mode.txt" 2>&1
      else
        CI=spec bundle exec ruby "${pre[@]}" -I lib "$here/$s.rb" > "$out/$s-$v-$mode.txt" 2>&1
      fi
      echo "$v $mode $s exit $? | $(grep -E 'differences|mismatch|differ' "$out/$s-$v-$mode.txt" | tail -n 1 | cut -c1-140)"
    done
  done
done
