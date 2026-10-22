# frozen_string_literal: true

# Bet V: load a pinned ruby/time source, never patch an app or installed gem.
# TIME_SOURCE=/absolute/lib/time.rb ruby bench/upstream/stdlib_time.rb probe|native|ir
require "json"
require "digest"
source = File.realpath(ENV.fetch("TIME_SOURCE"))
require source

module StdlibTime
  class Input < String; end
  class Clock < Time; end
  CASES = {
    "httpdate" => [:httpdate, "Sun, 06 Nov 1994 08:49:37 GMT"],
    "rfc2822" => [:rfc2822, "21 Nov 1997 09:55:06 -0630"],
    "no_seconds" => [:rfc2822, "21 Nov 049 09:55 -0630"],
    "obsolete_control" => [:httpdate, "Sunday, 06-Nov-94 08:49:37 GMT"],
    "iso_control" => [:iso8601, "1997-11-21T09:55:06-06:30"]
  }.freeze
  module_function

  def probe
    dates = ["Sun, 06 Nov 1994 08:49:37 GMT", "21 Nov 1997 09:55:06 -0630",
      "21 Nov 049 09:55 -0630", "21 Nov 050 09:55 -0630", "21 Nov 001 09:55:07 UT",
      "21 Nov 0001 09:55:07 -0000", "21 Nov 00 09:55:00 +0000",
      "21 nOv 1997 09:55:06 gMt (comment)", "21 Nov 1997 23:59:60 -0330",
      "Sunday, 06-Nov-94 08:49:37 GMT", "Sun Nov  6 08:49:37 1994",
      "", "not a date", "21 Nov 1997 09:55:06 +2500", "21 Nov 1997 09:55:06 Z",
      "21 Nov 1997 09:55:06 GMT\u00a0", "21 Növ 1997 09:55:06 GMT",
      "21 Nov 1997 09:55:06 GMT\xff".b]
    rows = []
    dates.each do |date|
      %w[UTF-8 US-ASCII ASCII-8BIT ISO-8859-1 UTF-16LE].each do |encoding|
        [String, Input].each do |klass|
          [false, true].each do |frozen|
            %i[rfc2822 rfc822 httpdate].each do |method|
              [Time, Clock].each do |clock|
                input = klass.new(date).force_encoding(encoding)
                input.freeze if frozen
                before = [input.bytes, input.encoding.name, input.frozen?]
                result = begin
                  value = clock.public_send(method, input)
                  other = clock.public_send(method, input)
                  raise "shared Time result" if value.equal?(other)
                  original = other.to_r
                  value.localtime(3600)
                  raise "aliased Time mutation" unless other.to_r == original
                  {"value" => other.to_r.to_s, "offset" => other.utc_offset,
                    "utc" => other.utc?, "zone" => other.zone, "class" => other.class.name,
                    "frozen" => other.frozen?}
                rescue ArgumentError, Encoding::CompatibilityError => error
                  {"error" => error.class.name, "message" => error.message.scrub}
                end
                raise "input changed" unless before == [input.bytes, input.encoding.name, input.frozen?]
                rows << [dates.index(date), encoding, klass.name, frozen, method, clock.name, result]
              end
            end
          end
        end
      end
    end
    # Independently derived expectations distinguish 3- from 4-digit years,
    # optional seconds, the 49/50 completion boundary, and asymmetric offsets.
    [["21 Nov 049 09:55 -0630", Time.utc(2049, 11, 21, 16, 25)],
      ["21 Nov 050 09:55:07 +0230", Time.utc(1950, 11, 21, 7, 25, 7)],
      ["21 Nov 0049 09:55:07 -0000", Time.utc(49, 11, 21, 9, 55, 7)]].each do |date, expected|
      raise "year/seconds/offset changed" unless Time.rfc2822(date) == expected
    end
    {"rows" => rows, "ownership" => "distinct mutable Time results; unchanged input bytes/encoding/frozen state"}
  end

  def native
    require_relative "../jit_stability"
    JitStability.assert_mode!
    CASES.to_h do |name, (method, date)|
      work = ->(n, _) { n.times { Time.public_send(method, date) } }
      work.call(30_000, nil)
      allocated = GC.stat(:total_allocated_objects)
      work.call(10_000, nil)
      allocated = (GC.stat(:total_allocated_objects) - allocated).fdiv(10_000)
      GC.start
      before = JitStability.enabled? ? JitStability.snapshot : nil
      start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      work.call(100_000, nil)
      elapsed = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - start
      after = JitStability.enabled? ? JitStability.snapshot : nil
      [name, {"cpu_ns" => elapsed * 10_000, "allocations" => allocated,
        "jit_before" => before, "jit_after" => after}]
    end
  end

  def ir
    require_relative "../request_pairs"
    require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
    JitStability.assert_mode!
    raise "interpreter only" unless JitStability.actual == "interpreter"
    cases = CASES.slice("httpdate", "no_seconds", "obsolete_control")
    work = ->(n, name) {
      method, date = cases.fetch(name)
      n.times { Time.public_send(method, date) }
    }
    cases.each_key { work.call(100, _1) }
    windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), cases.keys)
    anchors = HeapWindows.run(windows) { |n, key| work.call(n, key) }
    puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION,
      windows: windows, operations: true, heap_anchors: anchors,
      heap_page_targets: HeapWindows.page_targets, jit_warmup: nil)}"
  end
end

case ARGV.first
when "probe"
  puts JSON.generate(StdlibTime.probe)
when "native"
  puts JSON.generate(ruby: RUBY_DESCRIPTION, source_sha256: Digest::SHA256.file(source).hexdigest,
    cases: StdlibTime.native)
when "ir"
  StdlibTime.ir
else
  abort "usage: TIME_SOURCE=... ruby #{__FILE__} probe|native|ir"
end
