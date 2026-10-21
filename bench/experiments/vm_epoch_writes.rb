# frozen_string_literal: true

# Diagnostic native CPU-time cohort: identical 4.0.7 builds/flags, differing
# only by the epoch patch. No request speed claim or retry-to-green.
require "json"
require "open3"
require_relative "../request_pairs"

if ENV["EPOCH_WRITE_WORKER"]
  mode = ENV.fetch("EPOCH_WRITE_WORKER")
  klass = Class.new if mode == "definitions"
  1000.times { klass.define_method(:target) { 19 } } if klass
  3.times { GC.start }
  before = GC.stat
  t0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  if mode == "boot"
    require File.expand_path("config/application", Dir.pwd)
    Rails.application.config.yjit = false
    require File.expand_path("config/environment", Dir.pwd)
  else
    100_000.times { klass.define_method(:target) { 19 } }
  end
  cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t0
  after = GC.stat
  puts "EPOCH_WRITE #{JSON.generate(cpu_seconds: cpu, mode: mode,
    allocations: after[:total_allocated_objects] - before[:total_allocated_objects],
    collections: after[:count] - before[:count], ruby: RUBY_DESCRIPTION)}"
  exit
end

mode, app, output = ARGV
abort "usage: vm_epoch_writes.rb boot|definitions APP NEW_JSON" unless %w[boot definitions].include?(mode) && output
abort "output must be new" if File.exist?(output)
binaries = {"off_a" => ENV.fetch("EPOCH_BASELINE_RUBY"), "off_b" => ENV.fetch("EPOCH_BASELINE_RUBY"),
  "epoch" => ENV.fetch("EPOCH_PATCHED_RUBY")}
binaries["token"] = ENV.fetch("EPOCH_TOKEN_RUBY") if ENV["EPOCH_TOKEN_RUBY"]
rng = Random.new(41231)
samples = 6.times.map do
  binaries.keys.shuffle(random: rng).to_h do |arm|
    out, status = Open3.capture2e({"EPOCH_WRITE_WORKER" => mode}, binaries.fetch(arm),
      "--disable-yjit", "--disable-zjit", File.expand_path(__FILE__), chdir: app)
    raise out unless status.success?
    line = out.lines.find { _1.start_with?("EPOCH_WRITE ") }
    [arm, JSON.parse(line.delete_prefix("EPOCH_WRITE "))]
  end
end
effects = (binaries.keys - ["off_a"]).to_h do |arm|
  values = samples.map { 100 * (_1.fetch(arm).fetch("cpu_seconds") / _1.fetch("off_a").fetch("cpu_seconds") - 1) }
  [arm, RequestPairs.estimate(values, seed: 41231)]
end
File.write(output, JSON.pretty_generate(mode: mode, seed: 41231, binaries: binaries,
  source_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  hashes: binaries.transform_values { Digest::SHA256.file(_1).hexdigest }, samples: samples, percent: effects))
puts JSON.pretty_generate(percent: effects)
