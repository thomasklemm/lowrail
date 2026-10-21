#!/usr/bin/env ruby
# frozen_string_literal: true

# Export only measurement evidence, never private configs, fixture secrets,
# cookies, bodies or raw app logs. Input directories are retained unchanged.
require "json"
require "digest"

destination, *directories = ARGV
abort "usage: ruby docs/stack-report.rb OUTPUT.json SCREEN_DIRECTORY..." unless destination && !directories.empty?
reports = directories.map do |directory|
  result_path, screen_path = %w[result.json screen.json].map { File.join(directory, _1) }
  result, screen = [result_path, screen_path].map { JSON.parse(File.read(_1)) }
  config, pins = result.fetch("config"), result.fetch("pins")
  workers = result.fetch("workers").map do |worker|
    worker.slice("arm", "coverage", "round", "refusal", "ruby", "rails", "affinity", "boot_ms", "jit").merge(
      "routes" => worker.fetch("routes").transform_values do |row|
        row.reject { |key, _| key == "samples_us" }
      end,
      "exact" => worker.fetch("exact").transform_values do |seeds|
        seeds.transform_values do |row|
          row.slice("status", "body_sha256", "headers_sha256").merge(
            "evidence" => row.fetch("evidence").slice("passed", "errors", "db_unchanged", "db_gate", "db_sha256"))
        end
      end)
  end
  db_checks = workers.reject { _1.fetch("coverage") }.first.fetch("exact").keys.to_h do |route|
    rows = workers.reject { _1.fetch("coverage") }.map { _1.fetch("exact").fetch(route) }
    hashes = rows.flat_map { _1.values.map { |row| row.fetch("evidence")["db_sha256"] } }
    [route, hashes.all? ? {"covered" => true, "identical_across_all_arms_seeds_rounds" => hashes.uniq.size == 1,
      "sha256_values" => hashes.uniq} : {"covered" => false}]
  end
  {"name" => File.basename(directory), "scope" => result.fetch("scope"),
    "protocol" => config.slice("workload", "paths", "rounds", "warmup", "samples", "seed_number", "cpu"),
    "pins" => pins.slice("revision", "source_sha256", "script_sha256", "manifest_sha256", "lock_sha256", "ruby_sha256"),
    "artifact_units" => result.fetch("artifact_units"), "screen" => screen,
    "db_checks" => db_checks, "workers" => workers,
    "raw_result_sha256" => Digest::SHA256.file(result_path).hexdigest,
    "raw_screen_sha256" => Digest::SHA256.file(screen_path).hexdigest}
end

blog = reports.select { _1.fetch("protocol").fetch("workload") == "blog" }.to_h { [_1.fetch("name"), _1] }
effects = blog.transform_values do |report|
  route = report.fetch("screen").fetch("routes").fetch("GET /articles/1")
  values = route.fetch("allocation_samples").transform_values { _1.fetch("median") }
  {"allocations" => values, "objects_saved" => values.fetch("off_a") - values.fetch("on"),
    "exact" => report.fetch("screen").fetch("passed_exact"), "db" => report.fetch("db_checks")}
end
output = {"format" => 1, "scope" => "Exploratory stack screens; provisional, no production admission or published price",
  "reports" => reports, "blog_allocation_effects" => effects}
File.write(destination, JSON.pretty_generate(output) + "\n")
puts "#{reports.size} screens exported; no configs/secrets/bodies/logs included"
