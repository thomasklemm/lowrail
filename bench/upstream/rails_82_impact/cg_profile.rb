# frozen_string_literal: true

# One sampled Callgrind window (census 8's cpu_sampler.c, CENSUS_CPU_EXT) and
# its JSON: exact client Ir per unit, objects per unit, and sampled
# instructions per Ruby method (self, inclusive) and per line (self). A
# sample's self cost goes to its nearest Ruby frame, so C functions are
# charged to the Ruby method that called them; Callgrind's own output file
# (--callgrind-out-file) has the C functions. Measurement only.
module CgProfile
  module_function

  def site(path, rails_root)
    path = path.to_s
    return "<cfunc>" if path.empty? || path == "<cfunc>"
    return "RAILS/" + path.delete_prefix(rails_root + "/") if rails_root && path.start_with?(rails_root + "/")
    path.sub(%r{\A.*/gems/}, "GEM/").sub(%r{\A.*/benchmarks/}, "BENCH/").sub(%r{\A.*/\.corpus/}, "APP/")
  end

  # CG_PLAIN=PATH (bench/callgrind.c built as a shared library): no sampling;
  # Callgrind's dump holds only the window, for C-function self/inclusive costs.
  def plain(out, units, &work)
    require ENV.fetch("CG_PLAIN")
    GC.start unless ENV["CG_NO_GC_START"]
    g0 = GC.stat(:total_allocated_objects)
    gc0 = GC.count
    LowrailCallgrindBench.start
    work.call
    segments = LowrailCallgrindBench.finish
    require "json"
    File.write(out, JSON.generate(ruby: RUBY_DESCRIPTION, units: units, gc_segments: segments, gc_runs: GC.count - gc0,
      objects_per_unit: (GC.stat(:total_allocated_objects) - g0).fdiv(units)) + "\n")
  end

  def window(out, units, rails_root:, &work)
    return plain(out, units, &work) if ENV["CG_PLAIN"]
    require ENV.fetch("CENSUS_CPU_EXT")
    GC.start unless ENV["CG_NO_GC_START"]
    g0 = GC.stat(:total_allocated_objects)
    gcs = GC.count
    window = CensusCpu.measure(Integer(ENV.fetch("CG_SEED", "41231")), Integer(ENV.fetch("CG_INTERVAL", "8192")), &work)
    objects = GC.stat(:total_allocated_objects) - g0
    gcs = GC.count - gcs
    frames, stacks = CensusCpu.stacks
    keys = frames.map { |path, label, first| [site(path, rails_root), label.to_s, first] }
    weight = window[:work_ir].fdiv(window[:signals].nonzero? || 1) / units
    self_m, incl, lines, native = Hash.new(0), Hash.new(0), Hash.new(0), Hash.new(0)
    stacks.each do |stack, n|
      ruby = stack.index { |id, _| keys[id][0] != "<cfunc>" }
      if ruby
        self_m[keys[stack[ruby][0]]] += n
        lines[[keys[stack[ruby][0]][0], stack[ruby][1], keys[stack[ruby][0]][1]]] += n
      end
      # The innermost C method (Hash#[], String#gsub ...) when a sample is in one.
      native[keys[stack[0][0]][1]] += n if ruby != 0
      stack.map { |sid, _| keys[sid] }.uniq.each { incl[_1] += n }
    end
    require "json"
    File.write(out, JSON.generate(
      ruby: RUBY_DESCRIPTION, units: units, ir_per_unit: window[:work_ir].fdiv(units), gc_ir_per_unit: window[:gc] * weight,
      objects_per_unit: objects.fdiv(units), gc_runs: gcs, window: window,
      methods: incl.map { |k, n| { file: k[0], method: k[1], line: k[2], self: self_m[k] * weight, incl: n * weight } },
      lines: lines.map { |(f, l, m), n| { file: f, line: l, method: m, self: n * weight } },
      cfuncs: native.map { |m, n| { method: m, self: n * weight } }) + "\n")
  end
end
