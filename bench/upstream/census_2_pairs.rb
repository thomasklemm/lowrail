# frozen_string_literal: true

# RUBY_MASTER=/absolute/ruby ruby census_2_pairs.rb BASE DRAFT NEW_OUTPUT
require "json"
require "fileutils"
base, draft, output = ARGV.map { File.expand_path(_1) }
abort "output exists" if File.exist?(output)
FileUtils.mkdir_p(output)
ruby = ENV.fetch("RUBY_MASTER")
assets = ENV["CENSUS_TOPIC"] == "assets"
worker = File.expand_path(assets ? "preload_links.rb" : "census_2_worker.rb", __dir__)
modes = { interpreter: [], yjit: ["--yjit", "--yjit-stats=quiet"], zjit: ["--zjit", "--zjit-stats-quiet"] }
orders = %w[a b draft].permutation.to_a
paths = { "a" => base, "b" => base, "draft" => draft }
rows = []
12.times do |pair|
  modes.each do |mode, flags|
    orders[pair % orders.size].each do |arm|
      path = "#{output}/#{mode}-#{pair}-#{arm}.json"
      command = ["taskset", "-c", "2", ruby, *flags, worker, paths.fetch(arm), assets ? "sample" : path]
      log_options = assets ? { out: path, err: path + ".log" } : { out: path + ".log", err: [:child, :out] }
      abort "worker failed: #{path}" unless system(*command, **log_options)
      row = JSON.parse(File.read(path))
      if assets
        row["results"] = row.fetch("samples").map do |name, sample|
          sample.merge("case" => name, "seconds" => sample.fetch("cpu_ns") * 20_000 / 1e9)
        end
      end
      raise "mode mismatch" unless !!row["yjit"] == (mode == :yjit) && !!row["zjit"] == (mode == :zjit)
      rows << row.merge("mode" => mode, "pair" => pair, "arm" => arm)
    end
    puts "#{pair + 1}/12 #{mode} complete"
    $stdout.flush
  end
end

def interval(log_ratios)
  random = Random.new(41231)
  samples = Array.new(10_000) do
    Math.exp(Array.new(log_ratios.size) { log_ratios.sample(random: random) }.sum / log_ratios.size)
  end.sort
  [Math.exp(log_ratios.sum / log_ratios.size), samples[250], samples[9749]]
end

summary = modes.keys.flat_map do |mode|
  rows.first.fetch("results").map { _1.fetch("case") }.map do |name|
    arms = paths.keys.to_h do |arm|
      selected = rows.select { _1["mode"] == mode && _1["arm"] == arm }.sort_by { _1["pair"] }
      [arm, selected.map { |row| row["results"].find { _1["case"] == name } }]
    end
    ratios = %w[b draft].to_h do |arm|
      logs = arms.fetch("a").zip(arms.fetch(arm)).map { |a, b| Math.log(a["seconds"] / b["seconds"]) }
      [arm, interval(logs)]
    end
    { mode: mode, case: name, cpu_before_over_after: ratios,
      allocations: arms.transform_values { _1.map { |row| row["objects"] }.uniq } }
  end
end
File.write("#{output}/summary.json", JSON.pretty_generate(summary) + "\n")
File.write("#{output}/all.json", JSON.pretty_generate(rows) + "\n")
puts JSON.pretty_generate(summary)
