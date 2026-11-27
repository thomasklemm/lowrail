#!/usr/bin/env bash
# debug_page_matrix.sh: debug_page_probe.rb on 8.1.4.1 (3f290b759c), main (088fc0cf61) and the DV1 fix, with and
# without source extracts (STUB), interpreter and YJIT, two repetitions (the second is the A/A). Ruby 4.0.9.
cd "$(dirname "$0")"
export PATH=$(~/.local/bin/mise where ruby@4.0.9)/bin:$PATH
for jit in "" --yjit; do for rep in 1 2; do for t in r81 main dvc; do for s in 1 0; do
  R=/home/user/r82/probe-$t; [ $t = dvc ] && R=/home/user/r82/dvc
  echo "$t $(git -C $R rev-parse --short HEAD) rep$rep: $(STUB=$s ruby $jit -I$R/activesupport/lib -I$R/actionpack/lib -I$R/actionview/lib -I$R/activemodel/lib -I$R/railties/lib debug_page_probe.rb 2>/dev/null | tail -1)"
done; done; done; done > debug_page_results.txt
echo MATRIXDONE
