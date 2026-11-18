#!/usr/bin/env bash
# Site traces on a build (sampled, boot included): traces.sh NAME; summarize with ../../jit_parity_fxt.rb --depth 2.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd)
out=${OUT:-/tmp/zstats-traces-$1}; mkdir -p $out
for b in railsbench lobsters shipit; do
  RUBY_PREFIX=$HOME/rb/$1 $R/run.sh $b $b-trace $out --zjit-trace-exits-sample-rate=5 --zjit-trace-fallbacks-sample-rate=50 || echo FAILED $b
  f=$(ls -t /tmp/perfetto-*.fxt | head -1); mv "$f" $out/$b.fxt; echo "$b $(ls -la $out/$b.fxt)"
done
echo done
