# frozen_string_literal: true

require "json"
require "fileutils"
require "open3"
require_relative "../request_pairs"

# One finite diagnostic cohort. Never replaces the fixed-heap request screen.
config_path, output = ARGV
config = JSON.parse(File.read(config_path))
raise "fresh output required" if File.exist?(output)
FileUtils.mkdir_p(output)
File.write(File.join(output, "protocol.json"), JSON.pretty_generate(config))
worker = File.expand_path("gem_candidate.rb", __dir__)
samples = {}
rng = Random.new(41231)
config.fetch("candidates").each do |name, candidate|
  samples[name] = %w[interpreter yjit zjit].to_h do |mode|
    rows = Array.new(8) do |round|
      %w[off_a off_b on].shuffle(random: rng).to_h do |arm|
        source = candidate.fetch(arm == "on" ? "after" : "before")
        path = File.join(output, "#{name}-#{mode}-#{round}-#{arm}.json")
        flags = JitStability.flags(mode)
        flags += ["--yjit-stats=quiet"] if mode == "yjit"
        flags += ["--zjit-stats=quiet"] if mode == "zjit"
        env = {"BENCH_JIT" => mode, "RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil, "GEM_HOME" => nil, "GEM_PATH" => nil}
        stdout, stderr, status = Open3.capture3(env, "taskset", "-c", "2", config.fetch("ruby"), *flags,
          worker, name, candidate.fetch("base"), source, path)
        File.write(path + ".log", stdout + stderr)
        raise "failed worker: #{path}" unless status.success?
        [arm, JSON.parse(File.read(path))]
      end
    end
    snapshots = rows.flat_map(&:values).map { _1.fetch("snapshot") }
    raise "behavior differs: #{name}/#{mode}" unless snapshots.uniq.one?
    cases = rows.first.fetch("off_a").fetch("cases").keys.to_h do |case_name|
      metrics = rows.map { |row| row.transform_values { _1.fetch("cases").fetch(case_name) } }
      summary = RequestPairs.summarize(metrics, seed: 41231, tolerance: 5.0,
        metrics: %w[allocations cpu_us], controls: ["cpu_us"], zero_containment: false)
      summary[:windows] = metrics
      [case_name, summary]
    end
    [mode, cases]
  end
end
File.write(File.join(output, "summary.json"), JSON.pretty_generate(samples) + "\n")
