#!/bin/bash
# Callgrind Lobsters A/B on the probe copy, master then fix then master, back to back.
cd /home/user/workspace/repo/.corpus/census4-lobsters-gcprobe
export PATH=/tmp/w/valgrind-pinned/bin:$PATH CENSUS_WARMUP=30 BUNDLE_FROZEN=true RAILS_ENV=production RACK_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=fatal SKIP_TELEMETRY=1 APP_VERSION=census APP_HOST=localhost RUBY_YJIT_ENABLE=0 RUBY_ZJIT_ENABLE=0 CENSUS_MODE=interpreter DATABASE_ADAPTER=sqlite
unset RUBYOPT
out=/home/user/workspace/repo/.lowrail/private/ruby-41-watch
for step in "master-b51db981 cglobm1" "fix-kwsplat cglobf1" "master-b51db981 cglobm2" "fix-kwsplat cglobf2"; do
  set -- $step; rb=$1; label=$2
  mkdir -p $out/$label /tmp/w/cgdumps/$label
  CENSUS_CALLGRIND_EXT=/tmp/w/cg/$rb/lowrail_callgrind.so mise exec ruby@$rb -- bundle exec valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file \
    --callgrind-out-file=/tmp/w/cgdumps/$label/lobsters.cg --log-file=/tmp/w/cgdumps/$label/lobsters.cg.log \
    $(mise where ruby@$rb)/bin/ruby /home/user/workspace/repo/bench/upstream/rails_main_census_4.rb profile lobsters $out/$label/lobsters-interpreter.json > /tmp/w/logs/$label.log 2>&1
  echo "done $label"
done
echo ALL-DONE
sleep infinity
