# frozen_string_literal: true

# Finite, serial allocation/regression screen. Not a request-speed or Ir gate.
require "json"
require "digest"
require "fileutils"

output = File.expand_path(ARGV.fetch(0))
abort "fresh output required" if File.exist?(output)
kind = ARGV.fetch(1)
root = File.expand_path("../..", __dir__)
worker = File.join(__dir__, "workload_#{kind}.rb")
ruby = ENV.fetch("COHORT_RUBY")
gem_home = ENV.fetch("COHORT_GEM_HOME")
folder, source_file, source_env, savings = {
  "pg" => ["rails", "activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb", "RAILS_SOURCE",
    { "no_columns_control" => 0, "zero_rows" => -1, "one_column" => -1, "wide_32_columns" => -1, "unicode_binary_null" => -1 }],
  "tzinfo" => ["tzinfo", "lib/tzinfo/data_sources/zoneinfo_reader.rb", "TZINFO_SOURCE",
    { "format1_control" => 0, "positive_32" => 0, "negative_32" => -128, "signed_boundaries" => -12, "empty_control" => 0 }]
}.fetch(kind)
sources = { "base" => File.join(root, ".corpus/workload-#{folder}"), "draft" => File.join(root, ".corpus/workload-#{folder}-draft") }
flags = { "interpreter" => [], "yjit" => ["--yjit", "--yjit-stats=quiet"], "zjit" => ["--zjit", "--zjit-stats-quiet"] }
pins = sources.transform_values { |path| Digest::SHA256.file(File.join(path, source_file)).hexdigest }
random = Random.new(41231)
jobs = 12.times.flat_map do |round|
  flags.keys.product(%w[off_a off_b on]).shuffle(random: random).map { |mode, arm| { round: round, mode: mode, arm: arm } }
end
FileUtils.mkdir_p(output)
File.write(File.join(output, "protocol.json"), JSON.pretty_generate(
  scope: "allocation admission; CPU-time regression diagnostic only; no speed/Ir claim",
  rounds: 12, seed: 41231, warmup_per_case: 3000, allocation_operations: 2000, timed_operations: 10000,
  expected_objects_delta: savings,
  cpu: 0, ruby: ruby, worker_sha256: Digest::SHA256.file(worker).hexdigest, source_sha256: pins,
  flags: flags, jobs: jobs, bootstrap: { resamples: 5000, interval: 0.95, seed: 1729 },
  acceptance: "expected allocation delta in every mode and round; reject any positive paired CPU-time interval; retain rejected cohorts"
) + "\n")

jobs.each do |job|
  label = "%02d-%s-%s" % job.values_at(:round, :mode, :arm)
  source = job[:arm] == "on" ? "draft" : "base"
  env = { "GEM_HOME" => gem_home, "GEM_PATH" => gem_home, source_env => sources.fetch(source), "RUBYOPT" => nil }
  path = File.join(output, label + ".json")
  log = File.join(output, label + ".log")
  puts label
  $stdout.flush
  pid = Process.spawn(env, "taskset", "-c", "0", ruby, *flags.fetch(job[:mode]), worker, "measure", path, out: log, err: [:child, :out])
  Process.wait(pid)
  raise "worker failed: #{label}" unless $?.success?
  row = JSON.parse(File.read(path))
  raise "source changed: #{label}" unless row.fetch("source_sha256") == pins.fetch(source)
  raise "wrong mode: #{label}" unless row.fetch("yjit") == (job[:mode] == "yjit") && row.fetch("zjit") == (job[:mode] == "zjit")
end

def median(values)
  sorted = values.sort
  middle = sorted.size / 2
  sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
end

def interval(values)
  random = Random.new(1729)
  samples = 5000.times.map { median(Array.new(values.size) { values[random.rand(values.size)] }) }.sort
  [samples[124], samples[4874]]
end

summary = flags.keys.flat_map do |mode|
  rounds = 12.times.map do |round|
    %w[off_a off_b on].to_h do |arm|
      path = File.join(output, "%02d-%s-%s.json" % [round, mode, arm])
      [arm, JSON.parse(File.read(path)).fetch("measurements").to_h { [_1.fetch("case"), _1] }]
    end
  end
  rounds.first.fetch("on").keys.map do |label|
    objects = %w[off_a off_b on].to_h { |arm| [arm, median(rounds.map { _1.fetch(arm).fetch(label).fetch("objects") })] }
    cpu_deltas = rounds.map do |round|
      base = (round.fetch("off_a").fetch(label).fetch("seconds_per_operation") + round.fetch("off_b").fetch(label).fetch("seconds_per_operation")) / 2.0
      100 * (round.fetch("on").fetch(label).fetch("seconds_per_operation") / base - 1)
    end
    aa_deltas = rounds.map do |round|
      100 * (round.fetch("off_b").fetch(label).fetch("seconds_per_operation") / round.fetch("off_a").fetch(label).fetch("seconds_per_operation") - 1)
    end
    ci = interval(cpu_deltas)
    expected = savings.fetch(label)
    allocation_ok = rounds.all? do |round|
      a, b, on = %w[off_a off_b on].map { round.fetch(_1).fetch(label).fetch("objects") }
      (a - b).abs < 0.01 && (on - (a + b) / 2.0 - expected).abs < 0.01
    end
    { mode: mode, case: label, objects: objects, allocation_gate: allocation_ok,
      cpu_change_percent: median(cpu_deltas), cpu_95_percent: ci,
      aa_change_percent: median(aa_deltas), aa_95_percent: interval(aa_deltas),
      resolved_cpu_regression: ci.first > 0 }
  end
end
accepted = summary.all? { _1[:allocation_gate] && !_1[:resolved_cpu_regression] }
File.write(File.join(output, "summary.json"), JSON.pretty_generate(accepted: accepted, measurements: summary) + "\n")
puts JSON.pretty_generate(accepted: accepted, measurements: summary)
exit(accepted ? 0 : 1)
