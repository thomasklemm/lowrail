#!/bin/bash
# ips.sh ROUNDS OUTDIR : graphql-ruby's `rake bench:validate` (benchmark-ips), master and head alternating,
# pinned to CPU 1, Ruby 4.0.9, no JIT. Writes OUTDIR/<round>-<rev>.txt
rounds=$1; out=$2; mkdir -p $out
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
for r in $(seq 1 $rounds); do
  for rev in master head; do
    case $rev in master) d=/home/user/w/gm ;; head) d=/home/user/w/gh ;; esac
    (cd $d && echo "# $rev $(/usr/bin/git rev-parse HEAD) round $r $(date -u +%FT%TZ)" && BUNDLE_GEMFILE=$d/Gemfile taskset -c 1 bundle exec rake bench:validate) > $out/$r-$rev.txt 2>&1
  done
done
