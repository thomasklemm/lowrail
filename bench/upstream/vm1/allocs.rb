# frozen_string_literal: true

# VM1: allocation sites per request on P-MAP's Puma setup. After warmup, each
# workload runs VM1_REQUESTS requests with GC off and allocation tracing on;
# every object from the window is grouped by its allocation file and line,
# counted, and sized with ObjectSpace.memsize_of (slot plus malloc'd memory,
# at the end of the window).
#   hx CORPUS APP bundle exec ruby [--yjit] THIS APP OUT_JSON
# The in-process client's own lines (p_map/profile.rb) are left out.
require_relative "../p_map/profile"
require "objspace"

module VM1Allocs
  WARMUP = Integer(ENV.fetch("VM1_WARMUP", "100"))
  REQUESTS = Integer(ENV.fetch("VM1_REQUESTS", "10"))
  CLIENT = File.expand_path("../p_map/profile.rb", __dir__)
  KLASS = Kernel.instance_method(:class)

  module_function

  def run(name, output)
    RailsCensus.const_set(:Client, PMap::Client)
    server = PMap.start_puma
    ops = RailsCensus.workloads(name)
    ops += PMap.extra_ops(name, RailsCensus, ops)
    ops = ops.select { PMap::REQUEST_KINDS.include?(_1.kind) }
    only = ENV["PMAP_ONLY"]&.split(",")
    ops = ops.select { only.include?(_1.name) } if only
    reset = -> { RailsCensus.reset_side_effects }
    ops.each { |op| WARMUP.times { op.call.call; reset.call } }
    windows = ops.map do |op|
      GC.start
      gen = GC.count
      allocated = GC.stat(:total_allocated_objects)
      GC.disable
      ObjectSpace.trace_object_allocations_start
      REQUESTS.times { op.call.call; reset.call }
      ObjectSpace.trace_object_allocations_stop
      allocated = GC.stat(:total_allocated_objects) - allocated
      sites = Hash.new { |h, k| h[k] = [0, 0, Hash.new(0)] }
      ObjectSpace.each_object do |obj|
        next unless ObjectSpace.allocation_generation(obj) == gen
        file = ObjectSpace.allocation_sourcefile(obj) or next
        next if file == CLIENT
        site = sites["#{file}:#{ObjectSpace.allocation_sourceline(obj)}"]
        site[0] += 1
        site[1] += ObjectSpace.memsize_of(obj)
        klass = KLASS.bind_call(obj)
        site[2][klass ? klass.name || "anonymous" : "hidden"] += 1
      end
      ObjectSpace.trace_object_allocations_clear
      GC.enable
      top = sites.sort_by { -_2[0] }.first(300).map do |k, (n, bytes, classes)|
        [k, n.fdiv(REQUESTS), bytes.fdiv(REQUESTS), classes.sort_by { -_2 }.first(3).to_h { |c, m| [c, m.fdiv(REQUESTS)] }]
      end
      { name: op.name, kind: op.kind, requests: REQUESTS, objects_per_request: allocated.fdiv(REQUESTS),
        traced_per_request: sites.sum { _2[0] }.fdiv(REQUESTS), bytes_per_request: sites.sum { _2[1] }.fdiv(REQUESTS),
        sites: top }
    end
    server.stop(true)
    File.write(output, JSON.generate(app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?,
      rails: RailsCensus.rails_sha, set: ENV["CENSUS_SET"], windows: windows))
    puts JSON.generate(app: name, workloads: windows.size)
  end
end

if $PROGRAM_NAME == __FILE__
  name, output = ARGV
  RailsCensus.boot(name)
  VM1Allocs.run(name, output)
end
