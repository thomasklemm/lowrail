# frozen_string_literal: true

# Variant of bench/upstream/gem_request_census/prof.rb that does NOT fold Ruby's
# standard library and default gems into their callers: a frame under
# rubylibdir or in a default gem is owned by "std:<lib>". C functions and
# <internal:> frames still fold into their nearest Ruby caller. Adds:
#   cfuncs:   leaf C function name => samples (all owners), with the owner it was charged to
#   incl:     inclusive samples per gem/std method (counted once per sample)
#   incl_own: inclusive samples per gem/std owner (once per sample)
# Run exactly like prof.rb (via stdrun.rb).
require_relative "../census/harness"
unless $LOAD_PATH.any? { File.exist?(File.join(_1, "stackprof.rb")) }
  $LOAD_PATH.unshift(File.join(Dir[File.join(RbConfig::CONFIG["rubylibprefix"], "gems",
    RbConfig::CONFIG["ruby_version"], "gems", "stackprof-*")].max, "lib"))
end
require "stackprof"

module StdProf
  WAIT = Set[
    "IO#wait_readable", "IO#wait_writable", "IO#wait", "IO.select", "Kernel#sleep", "Kernel#select",
    "Thread::Queue#pop", "Thread::SizedQueue#pop", "Thread::ConditionVariable#wait", "Thread::Mutex#sleep",
    "Thread#join", "Thread#value", "IO#readpartial", "IO#sysread", "IO#read", "IO#gets", "BasicSocket#recv",
    "Socket#connect", "Socket#accept", "IO#read_nonblock", "IO#write_nonblock"
  ].freeze

  DEFAULT_GEMS = Dir[File.join(Gem.default_specifications_dir, "*.gemspec")]
    .map { File.basename(_1, ".gemspec").sub(/-[^-]+\z/, "") }.to_set.freeze
  LIBDIR = RbConfig::CONFIG.fetch("rubylibdir") + "/"

  module_function

  def owner(frame)
    file = frame[:file]
    return nil if file.nil? || file.empty? || file == "<cfunc>" || file.start_with?("<internal:")
    if file.start_with?(Rails.root.to_s + "/") then ["app", file.delete_prefix(Rails.root.to_s + "/")]
    elsif file.start_with?(RailsCensus.rails_dir + "/") then ["rails", file.delete_prefix(RailsCensus.rails_dir + "/")]
    elsif file.start_with?(LIBDIR)
      rel = file.delete_prefix(LIBDIR)
      lib = rel.sub(%r{\Ax86_64-linux/}, "").split(%r{[/.]}, 2).first
      ["std:#{lib}", "ruby/#{rel}"]
    elsif file.start_with?(RailsCensus::ROOT + "/") then ["harness", file.delete_prefix(RailsCensus::ROOT + "/")]
    elsif file.include?("/gems/") && (m = file.rpartition("/gems/").last.match(%r{\A([^/]+?)-(?:\d[^/]*|[0-9a-f]{12})/(.*)\z}))
      gem, path = m[1], m[2]
      harness = gem == "rack-test" || (gem == "rack" && path.match?(%r{\Alib/rack/mock(?:_request|_response)?\.rb\z}))
      kind = DEFAULT_GEMS.include?(gem) ? "std" : "gem"
      [harness ? "harness" : "#{kind}:#{gem}", "#{gem}/#{path}"]
    else ["other", file]
    end
  end

  def attribute(results)
    frames = results[:frames]
    raw = results[:raw] || []
    cache = {}
    tally = { samples: 0, gc: 0, wait: 0, owners: Hash.new(0), methods: Hash.new(0), cfuncs: Hash.new(0),
      incl: Hash.new(0), incl_own: Hash.new(0), std_callers: Hash.new(0), own_callers: Hash.new(0) }
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
      tally[:methods][found[1]] += count if found[0].match?(/\A(gem|std):/)
      tally[:cfuncs]["#{leaf[:name]} <#{found[0]}>"] += count if leaf[:file] == "<cfunc>"
      # For std-owned samples: the nearest frame owned by something other than std (who called the stdlib).
      # For gem/std-owned samples: the method, and the nearest frame with another owner (who called it).
      if found[0].match?(/\A(gem|std):/)
        caller = nil
        stack.reverse_each do |addr|
          o = cache.fetch(addr) { cache[addr] = (f = frames[addr]) && (ow = owner(f)) && [ow[0], "#{ow[1]}:#{f[:line]} #{f[:name]}"] }
          next unless o && o[0] != found[0]
          caller = o
          break
        end
        tally[:std_callers]["#{found[1]} <- #{caller ? "#{caller[0]} #{caller[1]}" : "none"}"] += count
        tally[:own_callers]["#{found[0]} <- #{caller ? caller[0] : "none"}"] += count
      end
      seen = {}
      seen_own = {}
      stack.each do |addr|
        o = cache.fetch(addr) { cache[addr] = (f = frames[addr]) && (ow = owner(f)) && [ow[0], "#{ow[1]}:#{f[:line]} #{f[:name]}"] }
        next unless o && o[0].match?(/\A(gem|std):/)
        seen[o[1]] = true
        seen_own[o[0]] = true
      end
      seen.each_key { tally[:incl][_1] += count }
      seen_own.each_key { tally[:incl_own][_1] += count }
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
    reps = Integer(ENV.fetch("CENSUS_REPS", "150"))
    interval = Integer(ENV.fetch("CENSUS_INTERVAL", "100"))
    objects_ops = Integer(ENV.fetch("CENSUS_OBJECT_OPS", "10"))
    rows = ops.map do |op|
      warmup.times { op.call.call; RailsCensus.reset_side_effects }
      GC.start
      cpu = 0.0
      reps.times do
        call = op.call
        t0 = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
        StackProf.start(mode: :wall, interval: interval, raw: true)
        call.call
        StackProf.stop
        cpu += Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - t0
        RailsCensus.reset_side_effects
      end
      results = StackProf.results
      tally = attribute(results)
      before = GC.stat(:total_allocated_objects)
      objects_ops.times do
        call = op.call
        StackProf.start(mode: :object, interval: 1, raw: true)
        call.call
        StackProf.stop
        RailsCensus.reset_side_effects
      end
      objects = attribute(StackProf.results).slice(:samples, :owners, :methods, :incl_own)
      { name: op.name, kind: op.kind, reps: reps, cpu_us_per_op: (cpu * 1e6 / reps).round(1),
        **tally, objects_ops: objects_ops, objects: objects }
    end
    File.write(out, JSON.pretty_generate(app: name, ruby: RUBY_DESCRIPTION, mode: RailsCensus.mode,
      rails: RailsCensus.rails_sha, interval_us: interval, workloads: rows) + "\n")
    puts "#{name}: #{rows.size} workloads -> #{out}"
  end
end

StdProf.run(*ARGV) if $PROGRAM_NAME == __FILE__
