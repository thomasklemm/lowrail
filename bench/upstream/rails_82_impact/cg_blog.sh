#!/bin/bash
# Callgrind window over a census app's GET pages (census_cg.rb), after a native
# priming run like census_ir_run.rb. CG_ROUNDS (16), CG_PLAIN (plain dump),
# CG_NO_GC_START=1 (no GC.start before the window, so GC work stays in), CG_SFX.
#   cg_blog.sh LABEL RAILS_SHA
l=$1; sha=$2; app=blog
SFX=${CG_PLAIN:+-plain}${CG_NO_GC_START:+-nogc}${CG_SFX}
O=/home/user/workspace/repo/.lowrail/private/imp2/cg; mkdir -p $O
dir=/home/user/workspace/repo/.corpus/census-$app; cd $dir
R=$(mise where ruby@4.0.9)/bin
export PATH=$R:$PATH; unset RUBYOPT GEM_HOME GEM_PATH
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
export BUNDLE_GEMFILE=$dir/Gemfile.census-${sha:0:12} BUNDLE_FROZEN=true RAILS_ENV=production RACK_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=fatal SKIP_TELEMETRY=1 APP_VERSION=census APP_HOST=localhost RUBY_YJIT_ENABLE=0 CENSUS_RAILS_SHA=$sha CENSUS_MODE=interpreter DISABLE_DATABASE_ENVIRONMENT_CHECK=1
export CG_PLAIN CG_NO_GC_START CENSUS_CPU_EXT=/home/user/src/ext/census_cpu_sampler.so CG_ROUNDS=${CG_ROUNDS:-16}
S=/home/user/workspace/repo/bench/upstream/rails_82_impact/census_cg.rb
# priming run (warm fragment caches), as census_ir_run.rb does
AVCPU_ROUNDS=1 AVCPU_WARMUP=3 ruby -rbundler/setup /home/user/workspace/repo/bench/upstream/actionview_cpu/census_ir.rb $app > $O/$app-$l.prime.log 2>&1 || { echo prime failed; exit 1; }
sh -c 'ulimit -d unlimited; exec "$@"' sh /home/user/c8-valgrind/bin/valgrind --tool=callgrind --instr-atstart=no --collect-atstart=yes --callgrind-out-file=$O/$app-$l$SFX.callgrind $R/ruby -rbundler/setup $S $app $O/$app-$l$SFX.json > $O/$app-$l$SFX.log 2>&1
echo "EXIT $?" >> $O/$app-$l$SFX.log
