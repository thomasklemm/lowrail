# frozen_string_literal: true

# Per census workload: how many ActiveSupport::SafeBuffer objects are made
# with `new` (every `html_safe` and every direct `SafeBuffer.new`), which line
# made them, whether the argument was already a SafeBuffer, and the workload's
# wall time per operation. Run inside a census copy with the census env:
#   bundle exec ruby [--yjit|--zjit] safebuffer_count.rb APP OUT.json
require_relative "../census/harness"

app, output = ARGV
raise "fresh output required" if File.exist?(output)
RailsCensus.boot(app)
ops = RailsCensus.workloads(app)
only = ENV["CENSUS_ONLY"]&.split(",")
ops = ops.select { only.include?(_1.name) } if only
warmup = Integer(ENV.fetch("CENSUS_WARMUP", "50"))
count = Integer(ENV.fetch("CENSUS_REQUESTS", "10"))
here = File.expand_path(__FILE__)
safety = "active_support/core_ext/string/output_safety.rb"

site = lambda do |loc|
  "#{RailsCensus.site_key(loc.absolute_path || loc.path)}:#{loc.lineno} #{loc.label}"
end

results = ops.map do |op|
  run = -> { op.call.call; RailsCensus.reset_side_effects }
  warmup.times { run.call }
  walls = 5.times.map do
    GC.start
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    20.times { run.call }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t) / 20.0
  end.sort
  news = 0
  safe_args = 0
  sites = Hash.new { |h, k| h[k] = [0, 0] }
  tp = TracePoint.new(:call) do |t|
    arg = t.binding.local_variable_get(:_str)
    safe = arg.is_a?(ActiveSupport::SafeBuffer)
    news += 1
    safe_args += 1 if safe
    locs = caller_locations(1, 12).reject { _1.absolute_path == here }
    # locs[0] is #initialize itself, then String.new (no Ruby frame), then the
    # caller of new: html_safe or a direct SafeBuffer.new.
    # The cfunc frame of `new` carries its caller's path; skip it.
    rest = locs.drop(1).drop_while { _1.label.match?(/[.#]new\z/) }
    html_safe = ->(l) { l.path.end_with?(safety) && l.label.end_with?("html_safe") }
    creator = rest.find { !html_safe.(_1) }
    via = rest.first && html_safe.(rest.first) ? "html_safe" : "new"
    idx = rest.index(creator)
    key = [via, creator ? site.(creator) : "?", idx && rest[idx + 1] ? site.(rest[idx + 1]) : "?"]
    row = sites[key]
    row[0] += 1
    row[1] += 1 if safe
  end
  tp.enable(target: ActiveSupport::SafeBuffer.instance_method(:initialize)) do
    count.times { run.call }
  end
  {
    workload: op.name, kind: op.kind, wall_ns_per_op_median: walls[2], wall_ns_per_op_min: walls[0],
    safebuffer_new_per_op: news.fdiv(count), already_safe_arg_per_op: safe_args.fdiv(count),
    sites: sites.sort_by { -_2[0] }.map { |(via, creator, parent), (n, s)| { via:, creator:, parent:, per_op: n.fdiv(count), already_safe_per_op: s.fdiv(count) } },
  }
end

File.write(output, JSON.pretty_generate(app:, ruby: RUBY_DESCRIPTION, mode: RailsCensus.mode, rails: RailsCensus.rails_sha,
  warmup:, requests: count, workloads: results) + "\n")
results.each { |r| puts format("%-50s %9.1f us %8.1f new/op %6.1f safe-arg/op", r[:workload][0, 50], r[:wall_ns_per_op_median] / 1000, r[:safebuffer_new_per_op], r[:already_safe_arg_per_op]) }
