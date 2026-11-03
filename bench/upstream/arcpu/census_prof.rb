# frozen_string_literal: true

# CPU profile of a census app's workloads (docs/upstream/activerecord-cpu.md).
# Run like the census harness, inside a census copy with its variant bundle:
#   CENSUS_RAILS_SHA=... CENSUS_MODE=interpreter|yjit BUNDLE_GEMFILE=Gemfile.census-SHA12 \
#     bundle exec ruby [--yjit] census_prof.rb APP OUT.dump [REPS]
# Each workload is warmed up (CENSUS_WARMUP, default 50), then all workloads
# run round-robin REPS times (default 40) under stackprof in wall mode at 200 µs
# (this orb's CPU timer fires at only 250 Hz). Side-effect resets run with the
# profiler paused, so only the operations themselves are sampled.
require_relative "../census/harness"
# stackprof is not in the apps' bundles; load the globally installed gem.
unless $LOAD_PATH.any? { File.exist?(File.join(_1, "stackprof.rb")) }
  $LOAD_PATH.unshift(File.join(Dir[File.join(RbConfig::CONFIG["rubylibprefix"], "gems",
    RbConfig::CONFIG["ruby_version"], "gems", "stackprof-*")].max, "lib"))
end
require "stackprof"

name, out, reps = ARGV
RailsCensus.boot(name)
ops = RailsCensus.workloads(name)
warmup = Integer(ENV.fetch("CENSUS_WARMUP", "50"))
ops.each { |op| warmup.times { op.call.call; RailsCensus.reset_side_effects } }
GC.start
StackProf.start(mode: :wall, interval: 200, raw: true, aggregate: true)
StackProf.stop
Integer(reps || 40).times do
  ops.each do |op|
    call = op.call
    StackProf.start(mode: :wall, interval: 200, raw: true, aggregate: true)
    call.call
    StackProf.stop
    RailsCensus.reset_side_effects
  end
end
File.binwrite(out, Marshal.dump(StackProf.results))
puts "#{name}: #{ops.size} workloads, profile #{out}"
