#!/usr/bin/env bash
# Callgrind instructions per javascript_importmap_tags call with a nonce: main, A/A, IM1 alone, combined.
# usage: run_ir.sh APP [yjit]   prints variant, Ir per call, objects per call, YJIT blocks compiled in the window
app=$1; mode=$2; here=$(cd "$(dirname "$0")" && pwd)
export PATH="$(~/.local/bin/mise where ruby@4.0.9)/bin:$PATH" RAILS_ENV=production SECRET_KEY_BASE=x NONCE=1 N=200
if [ "$mode" = yjit ]; then export YJIT=1; unset NO_YJIT; else export NO_YJIT=1; unset YJIT; fi
cd /home/user/workspace/imapps/$app
for v in main aa im1 comb; do
  gf=$v; [ $v = aa ] && gf=main
  out=$(BUNDLE_GEMFILE=Gemfile.$gf valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --callgrind-out-file=/dev/null ruby bin/rails runner $here/imp336_ir.rb 2>&1)
  ir=$(grep -o 'Collected : [0-9]*' <<<"$out" | grep -o '[0-9]*$')
  echo "$app ${mode:-interp} $v $(( ir / N )) $(grep -o 'objects=.*' <<<"$out")"
done
