# frozen_string_literal: true

# Instructions per round of a census app's GET page workloads, measured under
# Valgrind by running this twice with different AVCPU_ROUNDS and subtracting
# (see census_ir_run.rb). In a census copy, with script/census's environment:
#   CENSUS_MODE=interpreter AVCPU_ROUNDS=N bundle exec ruby [--yjit] census_ir.rb APP
# Boots like the allocation census (production, same controls), warms every
# GET page workload AVCPU_WARMUP times (default 30), then runs AVCPU_ROUNDS
# rounds of all of them. Only GET pages: the measured runs must not change the
# data the next run renders.
require_relative "../census/harness"

name = ARGV.fetch(0)
RailsCensus.boot(name)
ops = RailsCensus.workloads(name).select { _1.kind == :html }
abort "no GET page workloads" if ops.empty?
Integer(ENV.fetch("AVCPU_WARMUP", "30")).times { ops.each { _1.call.call } }
Integer(ENV.fetch("AVCPU_ROUNDS")).times { ops.each { _1.call.call } }
RailsCensus.reset_side_effects
warn "#{name}: #{ops.size} GET workloads (#{ops.map(&:name).join(", ")})"
