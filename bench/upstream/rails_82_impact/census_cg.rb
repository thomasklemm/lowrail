# frozen_string_literal: true

# Callgrind window over a census app's GET page workloads, with census 8's
# instruction sampler (cpu_sampler.c, under the patched Valgrind from
# `script/cpu-census build`). Same boot and warmup as census_ir.rb; then one
# window of CG_ROUNDS rounds. Run in a census copy with script/census's env:
#   valgrind --tool=callgrind --instr-atstart=no --collect-atstart=yes \
#     ruby -rbundler/setup census_cg.rb APP OUT.json
# OUT.json has exact window Ir per round, and sampled Ruby self/inclusive
# instructions per method and self per line (see cg_diff.rb).
require_relative "../census/harness"
require_relative "cg_profile"

name, out = ARGV.fetch(0), ARGV.fetch(1)
RailsCensus.boot(name)
ops = RailsCensus.workloads(name).select { _1.kind == :html }
abort "no GET page workloads" if ops.empty?
Integer(ENV.fetch("AVCPU_WARMUP", "30")).times { ops.each { _1.call.call } }
rounds = Integer(ENV.fetch("CG_ROUNDS", "16"))
CgProfile.window(out, rounds, rails_root: RailsCensus.rails_dir) { rounds.times { ops.each { _1.call.call } } }
RailsCensus.reset_side_effects
