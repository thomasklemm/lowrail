# frozen_string_literal: true

# Untimed contract controls. DB/cache changes are disposable data, never app
# source/config patches. The entry writer really is a separate process.
require "bundler/setup"
require "json"
require "digest"
require "fileutils"

app, state, destination = ARGV.map { File.expand_path(_1) }
abort "usage: lobsters_cache_controls.rb APP SEED NEW_JSON" unless destination && !File.exist?(destination)
require File.join(app, "config/environment")
require_relative "lobsters_cache_screen"
Exploration.install(config: {"app" => app, "exploration_only" => true}, state: state, arm: "on")
require "rack/mock"
rack = Rack::MockRequest.new(Rails.application)
headers = {"HTTPS" => "on", "HTTP_HOST" => "localhost", "HTTP_X_REQUEST_ID" => "lowrail-lobsters-sealed"}
routes = {"/" => "stories hottest=true page=1", "/s/enr7ye" => "story enr7ye"}
routes.each_key { |path| 10.times { raise "HTTP" unless rack.get(path, headers).status == 200 } }
raise "two actual plans required" unless LowrailCachePlan.plans.size == 2
report = {"ruby" => RUBY_DESCRIPTION, "rails" => Rails.version, "routes" => {}, "cache_controls" => []}

request = lambda do |path, seed, enabled|
  LowrailCachePlan.enabled = enabled
  response, evidence = Exploration.validation_request(route: "GET #{path}", seed: seed,
    request: -> { rack.get(path, headers) })
  raise "entropy or status" unless evidence.fetch("passed") && response.status == 200
  {"status" => response.status, "body_sha256" => Digest::SHA256.hexdigest(response.body),
    "headers_sha256" => Digest::SHA256.hexdigest(JSON.generate(response.headers.to_h.sort.to_h))}
end

routes.each do |path, key|
  LowrailCachePlan.enabled = false
  original = Rails.cache.read(key)
  cache_file = Rails.cache.send(:normalize_key, key, {})
  original_entry = File.binread(cache_file)
  original_times = [File.atime(cache_file), File.mtime(cache_file)]
  raise "warm cache required" unless original
  before = [0, 1].map { |seed| request.call(path, seed, false) }
  pid = fork do
    LowrailCachePlan.enabled = false
    value = Rails.cache.read(key)
    if path == "/"
      value.first.first.title = "Lowrail cache mutation control"
    else
      value.first.markeddown_comment = "<p>Lowrail cache mutation control</p>"
    end
    raise "write failed" unless Rails.cache.write(key, value, expires_in: 60)
    File.utime(*original_times, cache_file)
    exit! 0
  end
  Process.wait(pid)
  raise "writer failed" unless $?.success?
  hits_before = LowrailCachePlan.counters.fetch("hits", 0)
  after_on = [0, 1].map { |seed| request.call(path, seed, true) }
  after_off = [0, 1].map { |seed| request.call(path, seed, false) }
  row = {"external_writer" => true, "before" => before, "after_on" => after_on, "after_off" => after_off,
    "mtime_unchanged" => File.mtime(cache_file) == original_times.last,
    "exact" => after_on == after_off,
    "body_changed_both_seeds" => before.zip(after_on).all? { |a, b| a.fetch("body_sha256") != b.fetch("body_sha256") },
    "plan_hits_for_changed_bytes" => LowrailCachePlan.counters.fetch("hits", 0) - hits_before}
  raise "stale response" unless row.fetch("mtime_unchanged") && row.fetch("exact") &&
    row.fetch("body_changed_both_seeds") && row.fetch("plan_hits_for_changed_bytes").zero?
  report.fetch("routes")[path] = row
  Rails.cache.write(key, original, expires_in: 60)

  # Reads use live Entry metadata even when payload bytes already have a plan.
  expired = [false, true].map do |enabled|
    Rails.cache.write(key, original, expires_in: 0)
    LowrailCachePlan.enabled = enabled
    Rails.cache.read(key).nil?
  end
  Rails.cache.write(key, original, version: "new", expires_in: 60)
  mismatch = [false, true].map { |enabled| LowrailCachePlan.enabled = enabled; Rails.cache.read(key, version: "old").nil? }
  matched = [false, true].map { |enabled| LowrailCachePlan.enabled = enabled; !Rails.cache.read(key, version: "new").nil? }
  Rails.cache.delete(key)
  missing = [false, true].map { |enabled| LowrailCachePlan.enabled = enabled; Rails.cache.read(key).nil? }
  raise "metadata bypass" unless [expired, mismatch, matched, missing].flatten.all?
  report.fetch("cache_controls") << {"key" => key, "expired_off_on" => expired, "version_mismatch_off_on" => mismatch,
    "version_match_off_on" => matched, "missing_off_on" => missing}
  FileUtils.mkdir_p(File.dirname(cache_file))
  File.binwrite(cache_file, original_entry)
end

# Same result/alias graph and independent nested mutations, not just equality
# of AR IDs. Marshal.dump includes all cached associations and raw attributes.
report["copies"] = routes.values.to_h do |key|
  LowrailCachePlan.enabled = false
  stock = Rails.cache.read(key)
  LowrailCachePlan.enabled = true
  hits_before = LowrailCachePlan.counters.fetch("hits", 0)
  a, b = Rails.cache.read(key), Rails.cache.read(key)
  raise "copy plan must really run" unless LowrailCachePlan.counters.fetch("hits", 0) - hits_before == 2
  exact = Marshal.dump(stock) == Marshal.dump(a) && Marshal.dump(stock) == Marshal.dump(b)
  first_a = key.start_with?("stories ") ? a.first.first : a.first
  first_b = key.start_with?("stories ") ? b.first.first : b.first
  field = key.start_with?("stories ") ? "title" : "markeddown_comment"
  original_value = first_b.public_send(field).dup
  first_a.public_send(field).replace("local independent copy")
  independent = first_b.public_send(field) == original_value && !first_a.equal?(first_b) && !a.equal?(b)
  fresh = Rails.cache.read(key)
  fresh_first = key.start_with?("stories ") ? fresh.first.first : fresh.first
  independent &&= fresh_first.public_send(field) == original_value
  raise "copy contract: #{key}, exact=#{exact}, independent=#{independent}" unless exact && independent
  [key, {"exact_marshaled_graph" => exact, "nested_mutation_independent" => independent}]
end
report["counts"] = LowrailCachePlan.counters
report["passed"] = true
File.write(destination, JSON.pretty_generate(report), perm: 0o600)
puts "cache controls PASS: two external rewrites × two seeds; expiry/version/missing; equal independent mutable graphs"
