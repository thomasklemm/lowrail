# frozen_string_literal: true

# CPU profile of a census app's page workloads (kind :html, :turbo), run in a
# census copy with script/census's environment:
#   CENSUS_MODE=interpreter|yjit AVCPU_OUT=DIR bundle exec ruby [--yjit] census_profile.rb APP
# Boots the app exactly like the allocation census (production, same controls),
# warms every selected workload AVCPU_WARMUP times (default 50), then profiles
# AVCPU_OPS rounds (default 100) of all of them together and writes
# DIR/APP-MODE.json (see profile.rb). Per-workload wall time per operation
# (min of 5 rounds of 20, unprofiled) is printed too.
require_relative "../census/harness"
require_relative "profile"

name = ARGV.fetch(0)
RailsCensus.boot(name)
kinds = ENV.fetch("AVCPU_KINDS", "html,turbo").split(",").map(&:to_sym)
ops = RailsCensus.workloads(name).select { kinds.include?(_1.kind) }
abort "no page workloads" if ops.empty?
warn "erb: #{ActionView::Template::Handlers::ERB.erb_implementation}, ops: #{ops.map(&:name).join(", ")}"
Integer(ENV.fetch("AVCPU_WARMUP", "50")).times { ops.each { _1.call.call } }
RailsCensus.reset_side_effects
ops.each do |op|
  best = 5.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    20.times { op.call.call }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / 20
  end.min
  warn format("%-40s %8.1f us/op", op.name, best * 1e6)
end
rounds = Integer(ENV.fetch("AVCPU_OPS", "100"))
AvCpu.profile("#{name}-#{RailsCensus.mode}", ENV.fetch("AVCPU_OUT"), rails_dir: RailsCensus.rails_dir, app_dir: Rails.root.to_s) do
  rounds.times { ops.each { _1.call.call } }
end
RailsCensus.reset_side_effects
