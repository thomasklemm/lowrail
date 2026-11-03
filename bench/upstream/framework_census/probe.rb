# frozen_string_literal: true

# Framework census probes, run inside a census app copy with that copy's census
# bundle (see script/framework-probe):
#   ruby [--yjit] probe.rb work APP OUT.json     per-operation call counts
#   CALLERS="Klass#meth,Klass.meth" ruby probe.rb callers APP   caller locations
#
# work: after the harness's 50 warmups per workload, traces CENSUS_PROBE_OPS (5)
# operations with TracePoint and records, per workload and operation:
# * calls of every Ruby method defined in a Rails file (owner#name);
# * method_missing calls, by the owner that handles them and the caller line;
# * C calls of Hash#merge/merge!/update/reverse_merge/dup/transform_keys and
#   Array#dup/flatten/compact/uniq made from a Rails line, by that line;
# * ActiveSupport::Callbacks::CallbackChain#compile and its compile_sequence
#   (a compiled chain is memoized, so compile_sequence should stay at zero).
# Counts are calls, not time. They locate repeated framework work that does
# not show up as allocations; costs come from per-call micros.
require_relative "../census/harness"

module FrameworkProbe
  module_function

  C_CALLS = {
    Hash => %i[merge merge! update reverse_merge reverse_merge! dup transform_keys transform_keys! symbolize_keys stringify_keys
      deep_merge with_indifferent_access slice except],
    Array => %i[dup flatten compact uniq + -],
    Kernel => %i[respond_to? public_send send instance_variable_get dup],
    BasicObject => %i[__send__ instance_exec]
  }.freeze

  def rails_file?(path) = path&.start_with?(RailsCensus.rails_dir + "/")

  def short(path, line) = "#{RailsCensus.site_key(path)}:#{line}"

  def work(name, output)
    ops = RailsCensus.workloads(name)
    count = Integer(ENV.fetch("CENSUS_PROBE_OPS", "5"))
    run = ->(op) { op.call.call; RailsCensus.reset_side_effects }
    rails_files = Hash.new { |h, path| h[path] = rails_file?(path) }
    results = ops.map do |op|
      Integer(ENV.fetch("CENSUS_WARMUP", "50")).times { run.(op) }
      calls = Hash.new(0)
      missing = Hash.new(0)
      ccalls = Hash.new(0)
      tp_call = TracePoint.new(:call) do |tp|
        path = tp.path
        if tp.method_id == :method_missing
          loc = caller_locations(2, 1).first
          missing["#{tp.defined_class} <- #{short(loc&.path, loc&.lineno)}"] += 1
        end
        calls["#{tp.defined_class}##{tp.method_id}"] += 1 if rails_files[path]
      end
      tp_c = TracePoint.new(:c_call) do |tp|
        methods = C_CALLS[tp.defined_class] or next
        next unless methods.include?(tp.method_id)
        loc = caller_locations(1, 1).first
        next unless loc && rails_files[loc.path]
        ccalls["#{tp.defined_class}##{tp.method_id} @ #{short(loc.path, loc.lineno)}"] += 1
      end
      tp_call.enable { tp_c.enable { count.times { run.(op) } } }
      per = ->(h) { h.transform_values { _1.fdiv(count) }.sort_by { -_2 }.to_h }
      { workload: op.name, kind: op.kind, ops: count, calls: per.(calls), method_missing: per.(missing), c_calls: per.(ccalls) }
    end
    File.write(output, JSON.pretty_generate(app: name, mode: RailsCensus.mode, rails: RailsCensus.rails_sha,
      ruby: RUBY_DESCRIPTION, workloads: results) + "\n")
  end

  # Bet P1 (docs/upstream/actionpack-cpu.md): sample every request workload
  # with stackprof (wall clock, raw stacks) after the usual warmup, the same
  # number of operations per workload, into one dump per app and mode.
  # stackprof is loaded from the Ruby's own gem directory, outside the bundle.
  def prof(name, output)
    $LOAD_PATH.unshift(*Dir[File.join(Gem.default_dir, "gems/stackprof-*/lib")],
      *Dir[File.join(Gem.default_dir, "extensions/*/*/stackprof-*")])
    require "stackprof"
    ops = RailsCensus.workloads(name).reject { %i[job mail mailer].include?(_1.kind) }
    count = Integer(ENV.fetch("CENSUS_PROF_OPS", "100"))
    run = ->(op) { op.call.call; RailsCensus.reset_side_effects }
    ops.each { |op| Integer(ENV.fetch("CENSUS_WARMUP", "50")).times { run.(op) } }
    StackProf.run(mode: :wall, interval: Integer(ENV.fetch("CENSUS_PROF_INTERVAL", "200")), raw: true, out: output) do
      count.times { ops.each { |op| run.(op) } }
    end
    warn "#{name}: #{ops.size} request workloads x #{count} ops -> #{output}"
  end

  def callers(name)
    ops = RailsCensus.workloads(name)
    ops.each { |op| 3.times { op.call.call; RailsCensus.reset_side_effects } }
    # "Klass#meth" for instance methods, "Klass.meth" for singleton methods.
    wanted = ENV.fetch("CALLERS").split(",").to_h do |spec|
      owner, sep, meth = spec.rpartition(/[#.]/)
      owner = Object.const_get(owner)
      [[sep == "." ? owner.singleton_class : owner, meth.to_sym], spec]
    end
    depth = Integer(ENV.fetch("DEPTH", "2"))
    counts = Hash.new { |h, k| h[k] = Hash.new(0) }
    tp = TracePoint.new(:call, :c_call) do |t|
      spec = wanted[[t.defined_class, t.method_id]]
      next unless spec
      locs = caller_locations(2, depth)
      counts[spec][locs.map { short(_1.path, _1.lineno) }.join("  <-  ")] += 1
    end
    ops.each do |op|
      tp.enable { op.call.call }
      RailsCensus.reset_side_effects
    end
    counts.each do |spec, rows|
      puts "== #{name} #{spec} (#{rows.values.sum} calls over #{ops.size} workloads, one op each)"
      rows.sort_by { -_2 }.first(Integer(ENV.fetch("TOP", "8"))).each { |loc, n| puts format("%6d  %s", n, loc[0, 300]) }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  RailsCensus.boot(name)
  case command
  when "work" then FrameworkProbe.work(name, output)
  when "callers" then FrameworkProbe.callers(name)
  when "prof" then FrameworkProbe.prof(name, output)
  else abort "usage: probe.rb work APP OUT.json | prof APP OUT.dump | callers APP"
  end
end
