# frozen_string_literal: true

# Isolated C-path screen, not a Rails throughput benchmark.
# Build unchanged/patched ext/cgi/escape with identical flags and put each
# escape.so and lib/cgi/escape.rb under its own LIB/cgi/ directory.
# Usage: mise exec ruby@4.0.7 -- ruby THIS BASE_LIB PATCH_LIB OUTPUT [ROUNDS]
# For String initialization, SCREEN_KIND=string_init takes two Ruby executables.
# SCREEN_RUBY may name another Ruby executable (e.g. an uninstalled master).
# SCREEN_RUBYLIB supplies only the child runtime's extra library paths.

kind = ENV.fetch("SCREEN_KIND", "cgi")
cases = kind == "string_init" ? {
  "string_short" => ["article_title", 2_000_000],
  "subclass_short" => ["article_title", 2_000_000],
  "subclass_long" => ["a" * 2048, 2_000_000],
  "forward_short" => ["article_title", 2_000_000],
  "keywords" => ["article_title", 1_000_000],
  "no_args" => ["", 2_000_000],
} : {
  "empty" => ["", 1_500_000],
  "safe_short" => ["article_title", 1_000_000],
  "safe_long" => ["a" * 2048, 150_000],
  "escape_early" => ["<" + "a" * 2047, 120_000],
  "escape_late" => ["a" * 2047 + "<", 150_000],
  "dense" => ["<&'\">" * 16, 300_000],
  "utf8" => ["\u3042" * 682, 150_000],
  "invalid_utf8" => [("\xFF" * 2048).force_encoding(Encoding::UTF_8), 150_000],
  "nul" => ["a\0b" * 682, 150_000],
}

if ARGV.first == "--worker"
  _, name, arm, scale = ARGV
  input, iterations = cases.fetch(name)
  iterations = (iterations * Float(scale)).ceil
  input.freeze
  if kind == "cgi"
    require "cgi/escape"
    expected = input.b.gsub(/[<&'">]/, "<" => "&lt;", "&" => "&amp;",
      "'" => "&#39;", '"' => "&quot;", ">" => "&gt;").force_encoding(input.encoding)
    actual = CGI.escapeHTML(input)
    raise "wrong output" unless actual == expected && actual.encoding == input.encoding &&
      !actual.frozen? && !actual.equal?(input)
    loop_body = ->(n) { n.times { CGI.escapeHTML(input) } }
  else
    class ScreenString < String; end
    class ForwardString < String
      def initialize(str = "")
        super
      end
    end
    loop_body = case name
    when "string_short" then ->(n) { n.times { String.new(input) } }
    when "subclass_short", "subclass_long" then ->(n) { n.times { ScreenString.new(input) } }
    when "forward_short" then ->(n) { n.times { ForwardString.new(input) } }
    when "keywords" then ->(n) { n.times { ScreenString.new(input, encoding: "UTF-8") } }
    when "no_args" then ->(n) { n.times { ScreenString.new } }
    end
    raise "wrong subclass initialization" unless ScreenString.new(input) == input &&
      ScreenString.new(input).encoding == input.encoding && ForwardString.new(input) == input
  end

  loop_body.call(50_000)
  GC.start
  allocations = GC.stat(:total_allocated_objects)
  cpu_start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  wall_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  loop_body.call(iterations)
  wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall_start
  cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu_start
  objects = GC.stat(:total_allocated_objects) - allocations
  STDOUT.binmode
  STDOUT.write(Marshal.dump({case: name, arm: arm, kind: kind, iterations: iterations,
    ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, cpu_ns: cpu * 1e9 / iterations,
    wall_ns: wall * 1e9 / iterations, objects: objects.fdiv(iterations),
    extension: $LOADED_FEATURES.find { |path| path.end_with?("/cgi/escape.so") }}))
  exit
end

require "json"
require "open3"
require "rbconfig"
require "digest"

baseline, patched, output, rounds = ARGV
abort "usage: #{$0} BASE_LIB PATCH_LIB OUTPUT [ROUNDS]" unless output
rounds = Integer(rounds || 16)
scale = ENV.fetch("SCREEN_SCALE", "1")
names = ENV.fetch("SCREEN_CASES", cases.keys.join(",")).split(",")
modes = ENV.fetch("SCREEN_MODES", "int,yjit").split(",")
ruby = ENV.fetch("SCREEN_RUBY", RbConfig.ruby)
libs = {"A1" => File.expand_path(baseline), "A2" => File.expand_path(baseline),
  "P1" => File.expand_path(patched), "P2" => File.expand_path(patched)}
result = {protocol: "16 default paired ABBA/BAAB rounds, fresh process per arm/case; 50k warmup; normal GC; CPU and wall; percentile paired bootstrap 20k, seed 22459; no multiple-comparison correction; positive delta is slower; A/A compares A2 with A1",
  kind: kind, rounds: rounds, scale: scale, hashes: libs.transform_values { |lib|
    Digest::SHA256.file(kind == "cgi" ? File.join(lib, "cgi/escape.so") : lib).hexdigest }, rows: [], summary: []}
rng = Random.new(22459)
interval = ->(values) do
  boot = Array.new(20_000) do
    sum = 0.0
    values.size.times { sum += values[rng.rand(values.size)] }
    sum / values.size
  end.sort
  {mean: values.sum / values.size, low: boot[499], high: boot[19_499]}
end

modes.each do |mode|
  names.each do |name|
    cohort = []
    rounds.times do |round|
      order = round.even? ? %w[A1 P1 P2 A2] : %w[P1 A1 A2 P2]
      rows = order.to_h do |arm|
        args = [kind == "cgi" ? ruby : libs.fetch(arm), "--disable-gems",
          mode == "yjit" ? "--yjit" : "--disable-yjit"]
        args << "-I#{libs.fetch(arm)}" if kind == "cgi"
        args += [File.expand_path(__FILE__), "--worker", name, arm, scale]
        stdout, stderr, status = Open3.capture3({"RUBYOPT" => nil,
          "RUBYLIB" => ENV["SCREEN_RUBYLIB"]}, *args)
        abort "#{args.inspect}: #{stderr}" unless status.success?
        row = Marshal.load(stdout)
        raise "wrong execution mode" unless row.fetch(:yjit) == (mode == "yjit")
        result[:rows] << row.merge(mode: mode, round: round)
        [arm, row]
      end
      cohort << rows
      File.write(output, JSON.pretty_generate(result) + "\n")
    end
    summary = {mode: mode, case: name}
    %i[cpu_ns wall_ns objects].each do |metric|
      summary[metric] = {
        baseline: cohort.sum { |r| (r["A1"][metric] + r["A2"][metric]) / 2.0 } / rounds,
        patched: cohort.sum { |r| (r["P1"][metric] + r["P2"][metric]) / 2.0 } / rounds,
        delta_percent: interval.call(cohort.map { |r|
          100.0 * ((r["P1"][metric] + r["P2"][metric]) / (r["A1"][metric] + r["A2"][metric]) - 1) }),
        aa_percent: interval.call(cohort.map { |r| 100.0 * (r["A2"][metric] / r["A1"][metric] - 1) })}
    end
    result[:summary] << summary
    File.write(output, JSON.pretty_generate(result) + "\n")
    warn "#{mode} #{name}: CPU #{summary[:cpu_ns][:delta_percent]}, A/A #{summary[:cpu_ns][:aa_percent]}"
  end
end
