# frozen_string_literal: true

# Request-time CPU attributed to gem code (docs/upstream/gem-request-census.md).
# Run like the census harness, inside a census copy with its variant bundle:
#   CENSUS_RAILS_SHA=... CENSUS_MODE=interpreter|yjit BUNDLE_GEMFILE=Gemfile.census-SHA12 \
#     bundle exec ruby [--yjit] prof.rb APP OUT.json
# Every workload (requests, jobs, mailers) is warmed up (CENSUS_WARMUP, default
# 50), then run CENSUS_REPS times (default 200) under stackprof in wall mode at
# 100 µs with raw stacks; side-effect resets run with the profiler stopped.
# Each sample is attributed to the leafmost frame that belongs to the app,
# Rails or a gem: C functions, <internal:...> frames and Ruby's standard library
# and its default gems (except json, wherever the bundle installs them) are folded into their caller. Samples
# whose leaf is a blocking call (I/O wait, sleep, queue pop) are counted as
# wait, collector samples as GC; neither is attributed. Then CENSUS_OBJECT_OPS
# (default 10) more operations run under stackprof's object mode at interval 1,
# which records every allocation with its stack, attributed the same way.
require_relative "../census/harness"
unless $LOAD_PATH.any? { File.exist?(File.join(_1, "stackprof.rb")) }
  $LOAD_PATH.unshift(File.join(Dir[File.join(RbConfig::CONFIG["rubylibprefix"], "gems",
    RbConfig::CONFIG["ruby_version"], "gems", "stackprof-0.2.28")].max, "lib"))
end
require "stackprof"

module GemRequestCensus
  WAIT = Set[
    "IO#wait_readable", "IO#wait_writable", "IO#wait", "IO.select", "Kernel#sleep", "Kernel#select",
    "Thread::Queue#pop", "Thread::SizedQueue#pop", "Thread::ConditionVariable#wait", "Thread::Mutex#sleep",
    "Thread#join", "Thread#value", "IO#readpartial", "IO#sysread", "IO#read", "IO#gets", "BasicSocket#recv",
    "Socket#connect", "Socket#accept", "IO#read_nonblock", "IO#write_nonblock"
  ].freeze

  # Ruby's default gems count as the standard library, except json (as in
  # script/census rank --gem all).
  DEFAULT_GEMS = (Dir[File.join(Gem.default_specifications_dir, "*.gemspec")]
    .map { File.basename(_1, ".gemspec").sub(/-[^-]+\z/, "") } - %w[json]).to_set.freeze

  module_function

  # [owner, key] for a frame, or nil when it folds into its caller.
  def owner(frame)
    file = frame[:file]
    return nil if file.nil? || file.empty? || file == "<cfunc>" || file.start_with?("<internal:")
    if file.start_with?(Rails.root.to_s + "/") then ["app", file.delete_prefix(Rails.root.to_s + "/")]
    elsif file.start_with?(RailsCensus.rails_dir + "/") then ["rails", file.delete_prefix(RailsCensus.rails_dir + "/")]
    elsif file.start_with?(RbConfig::CONFIG.fetch("rubylibdir") + "/") then nil
    elsif file.start_with?(RailsCensus::ROOT + "/") then ["harness", file.delete_prefix(RailsCensus::ROOT + "/")]
    elsif file.include?("/gems/") && (m = file.rpartition("/gems/").last.match(%r{\A([^/]+?)-(?:\d[^/]*|[0-9a-f]{12})/(.*)\z}))
      gem, path = m[1], m[2]
      harness = gem == "rack-test" || (gem == "rack" && path.match?(%r{\Alib/rack/mock(?:_request|_response)?\.rb\z}))
      return nil if DEFAULT_GEMS.include?(gem)
      [harness ? "harness" : "gem:#{gem}", "#{gem}/#{path}"]
    else ["other", file]
    end
  end

  def attribute(results)
    frames = results[:frames]
    raw = results[:raw] || []
    cache = {}
    tally = { samples: 0, gc: 0, wait: 0, owners: Hash.new(0), methods: Hash.new(0), leaves: Hash.new(0) }
    i = 0
    while i < raw.size
      len = raw[i]
      stack = raw[i + 1, len]
      count = raw[i + 1 + len]
      i += len + 2
      tally[:samples] += count
      leaf = frames[stack.last]
      if leaf.nil? || leaf[:name].start_with?("(")
        tally[:gc] += count
        next
      end
      if WAIT.include?(leaf[:name])
        tally[:wait] += count
        next
      end
      found = nil
      stack.reverse_each do |addr|
        found = cache.fetch(addr) { cache[addr] = (f = frames[addr]) && (o = owner(f)) && [o[0], "#{o[1]}:#{f[:line]} #{f[:name]}"] }
        break if found
      end
      found ||= ["other", "<no owner>"]
      tally[:owners][found[0]] += count
      if found[0].start_with?("gem:")
        tally[:methods][found[1]] += count
        tally[:leaves]["#{found[0]} #{leaf[:name]}"] += count if leaf[:file] == "<cfunc>"
      end
    end
    tally
  end

  def run(name, out)
    raise "fresh output required" if File.exist?(out)
    RailsCensus.boot(name)
    ops = RailsCensus.workloads(name)
    only = ENV["CENSUS_ONLY"]&.split(",")
    ops = ops.select { only.include?(_1.name) } if only
    warmup = Integer(ENV.fetch("CENSUS_WARMUP", "50"))
    reps = Integer(ENV.fetch("CENSUS_REPS", "200"))
    interval = Integer(ENV.fetch("CENSUS_INTERVAL", "100"))
    objects_ops = Integer(ENV.fetch("CENSUS_OBJECT_OPS", "10"))
    rows = ops.map do |op|
      warmup.times { op.call.call; RailsCensus.reset_side_effects }
      GC.start
      cpu = wall = 0.0
      reps.times do
        call = op.call
        t0 = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
        w0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        StackProf.start(mode: :wall, interval: interval, raw: true)
        call.call
        StackProf.stop
        wall += Process.clock_gettime(Process::CLOCK_MONOTONIC) - w0
        cpu += Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - t0
        RailsCensus.reset_side_effects
      end
      results = StackProf.results
      tally = attribute(results).merge(gc_samples: results[:gc_samples], missed: results[:missed_samples])
      objects_ops.times do
        call = op.call
        StackProf.start(mode: :object, interval: 1, raw: true)
        call.call
        StackProf.stop
        RailsCensus.reset_side_effects
      end
      objects = attribute(StackProf.results).slice(:samples, :owners, :methods)
      { name: op.name, kind: op.kind, reps: reps, cpu_us_per_op: (cpu * 1e6 / reps).round(1),
        wall_us_per_op: (wall * 1e6 / reps).round(1), **tally, objects_ops: objects_ops, objects: objects }
    end
    File.write(out, JSON.pretty_generate(app: name, ruby: RUBY_DESCRIPTION, mode: RailsCensus.mode,
      rails: RailsCensus.rails_sha, interval_us: interval, workloads: rows) + "\n")
    puts "#{name}: #{rows.size} workloads -> #{out}"
  end
end

GemRequestCensus.run(*ARGV) if $PROGRAM_NAME == __FILE__
