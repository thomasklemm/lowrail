# frozen_string_literal: true

# Paired CPU-pinned fresh processes, no concurrent tests/builds during timing.
# ruby preload_pairs.rb BEFORE AFTER RUBY_BINARY CPU NEW_DIRECTORY
require "json"
require "open3"
require "fileutils"
before, after, ruby, cpu, output = ARGV
abort "usage: preload_pairs.rb BEFORE AFTER RUBY CPU NEW_DIRECTORY" unless output
raise "fresh output required" if File.exist?(output)
FileUtils.mkdir_p(output)
worker = File.expand_path("preload_links.rb", __dir__)
results = {}
%w[interpreter yjit zjit].each do |mode|
  flags = case mode
  when "interpreter" then []
  when "yjit" then ["--yjit", "--yjit-stats=quiet"]
  when "zjit" then ["--zjit", "--zjit-stats-quiet"]
  end
  results[mode] = 10.times.map do |pair|
    row = {}
    # Five AB and five BA pairs, predetermined and balanced.
    order = pair.even? ? %w[before after] : %w[after before]
    order.each do |arm|
      checkout = arm == "before" ? before : after
      stdout, stderr, status = Open3.capture3({ "RUBYOPT" => nil, "RUBY_YJIT_ENABLE" => nil, "RUBY_ZJIT_ENABLE" => nil },
        "taskset", "-c", cpu, ruby, *flags, worker, checkout, "sample")
      File.write(File.join(output, "#{mode}-#{pair}-#{arm}.log"), stderr)
      raise "worker failed: #{stderr}" unless status.success?
      row[arm] = JSON.parse(stdout)
      raise "wrong execution mode" unless row[arm].fetch("yjit") == (mode == "yjit") && row[arm].fetch("zjit") == (mode == "zjit")
      File.write(File.join(output, "#{mode}-#{pair}-#{arm}.json"), JSON.pretty_generate(row[arm]))
    end
    row.merge("order" => order)
  end
end
rng = Random.new(41231)
summary = results.to_h do |mode, pairs|
  rows = pairs.first.fetch("before").fetch("samples").keys.to_h do |scenario|
    effects = pairs.map { Math.log(_1.fetch("before").fetch("samples").fetch(scenario).fetch("cpu_ns") / _1.fetch("after").fetch("samples").fetch(scenario).fetch("cpu_ns")) }
    boots = Array.new(10_000) { Array.new(effects.size) { effects.fetch(rng.rand(effects.size)) }.sum / effects.size }.sort
    [scenario, { speedup: Math.exp(effects.sum / effects.size), ci95: [Math.exp(boots[249]), Math.exp(boots[9749])],
      before_objects: pairs.map { _1.fetch("before").fetch("samples").fetch(scenario).fetch("objects") },
      after_objects: pairs.map { _1.fetch("after").fetch("samples").fetch(scenario).fetch("objects") } }]
  end
  [mode, rows]
end
File.write(File.join(output, "summary.json"), JSON.pretty_generate(summary) + "\n")
puts JSON.pretty_generate(summary)
