#!/usr/bin/env bash
# Interleaved benchmark-ips runs on one pinned core, 5 rounds; raw output to OUT/.
# usage: run_ips.sh OUT
out=$1; mkdir -p "$out"
export PATH="$(~/.local/bin/mise where ruby@4.0.9)/bin:$PATH" RAILS_ENV=production SECRET_KEY_BASE=x
script=$(cd "$(dirname "$0")" && pwd)/imp336_ips.rb
for round in 1 2 3 4 5; do
  for app in blog blog50; do
    for nonce in 0 1; do
      if [ $nonce = 1 ]; then variants="main aa im1 comb"; else variants="main aa comb"; fi
      for v in $variants; do
        gf=$v; [ $v = aa ] && gf=main
        if [ $nonce = 1 ]; then export NONCE=1; else unset NONCE; fi
        (cd /home/user/workspace/imapps/$app && BUNDLE_GEMFILE=Gemfile.$gf taskset -c 1 bin/rails runner $script) > "$out/$app-n$nonce-$v-r$round.txt" 2>&1
      done
    done
  done
done
echo DONE > "$out/DONE"
