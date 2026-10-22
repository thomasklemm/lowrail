# frozen_string_literal: true

# Off-only, diagnostic census. Run from the unchanged app's cwd. All output
# belongs outside the app; no source delivery or Lowrail setup is installed.
require "bundler/setup"
require "json"
require "digest"
require "objspace"

app, mode, output = ARGV
abort "usage: default_tier_census.rb blog|fizzy|lobsters|campfire allocations|instructions|profile NEW_JSON" unless
  %w[blog fizzy lobsters campfire].include?(app) && %w[allocations instructions profile].include?(mode) && output
abort "new external output required" if File.exist?(output) || File.expand_path(output).start_with?(Dir.pwd + "/")
abort "off only" unless ENV["LOWRAIL"] == "0" && !defined?(Lowrail)
require File.expand_path("config/application")
Rails.application.config.yjit = false
require File.expand_path("config/environment")
raise "Ruby 4.0.7 / Rails 8.1.4 interpreter required" unless
  RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4" && !RubyVM::YJIT.enabled?
Rails.logger.level = :error
ActiveRecord::Base.logger = nil

if app == "lobsters"
  # Upstream benchmark.rb restores this same shipped DB into :memory:.
  file = SQLite3::Database.new("db/production.sqlite3")
  backup = SQLite3::Backup.new(ActiveRecord::Base.connection.raw_connection, "main", file, "main")
  backup.step(-1)
  backup.finish
  file.close
end
require "rack/mock"
route = {"blog" => "/articles/1", "fizzy" => "/buckets", "lobsters" => "/", "campfire" => "/session/new"}.fetch(app)
headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "default-tier-census",
  "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0"}
headers.merge!(JSON.parse(File.read(ENV.fetch("CENSUS_HEADERS")))) if app == "fizzy"
client = Rack::MockRequest.new(Rails.application)
response_bytes = nil
request = -> do
  response = client.get(route, headers)
  raise "#{route}: HTTP #{response.status}" unless response.status == 200
  response_bytes = response.body.bytesize
  nil
end
normalize = ->(path) do
  path.to_s.sub(Dir.pwd + "/", "APP/").sub(%r{\A.*/gems/}, "GEM/").
    sub(RbConfig::CONFIG.fetch("rubylibdir") + "/", "RUBY/").
    sub(File.expand_path("../..", __dir__) + "/", "LOWRAIL/")
end
lock = ENV["BUNDLE_GEMFILE"] ? ENV.fetch("BUNDLE_GEMFILE") + ".lock" : "Gemfile.lock"
result = {app: app, route: route, mode: mode, ruby: RUBY_DESCRIPTION, rails: Rails.version,
  yjit: RubyVM::YJIT.enabled?, lock_sha256: Digest::SHA256.file(lock).hexdigest,
  script_sha256: Digest::SHA256.file(__FILE__).hexdigest}

if mode == "allocations"
  # Observe original compiled templates, without adding methods or a handler.
  scripts = []
  trace = TracePoint.new(:script_compiled) { |event| scripts << event.instruction_sequence }
  trace.enable { 10.times { request.call } }
  compiled = []
  visit = ->(iseq) do
    if iseq.path.include?("/app/views/")
      data = iseq.to_a
      ops = data.last.grep(Array)
      compiled << {path: normalize.call(iseq.path), label: iseq.label,
        operations: ops.group_by(&:first).transform_values(&:size),
        sends: ops.filter_map { |op| op[1][:mid].to_s if Hash === op[1] && op[1].key?(:mid) }.tally}
    end
    iseq.each_child { visit.call(_1) }
  end
  scripts.each { visit.call(_1) }
  result[:compiled_templates] = compiled.uniq
  scripts.clear
  warmup = 400
  warmup.times { request.call }
  result[:warmup] = warmup + 10
  result[:totals] = 3.times.map do
    3.times { GC.start }
    before = GC.stat
    100.times { request.call }
    after = GC.stat
    %i[total_allocated_objects minor_gc_count major_gc_count].to_h { [_1, after[_1] - before[_1]] }
  end
  3.times { GC.start }
  ObjectSpace.trace_object_allocations_clear
  raise "app disabled GC" if GC.disable
  generation = GC.count
  before = GC.stat(:total_allocated_objects)
  ObjectSpace.trace_object_allocations_start
  20.times { request.call }
  ObjectSpace.trace_object_allocations_stop
  result[:gc_allocated_objects] = GC.stat(:total_allocated_objects) - before
  result[:requests] = 20
  sites = Hash.new(0)
  ObjectSpace.each_object do |object|
    next unless ObjectSpace.allocation_generation(object) == generation
    source = ObjectSpace.allocation_sourcefile(object)
    next unless source
    klass = Object.instance_method(:class).bind_call(object)
    sites[[normalize.call(source), ObjectSpace.allocation_sourceline(object), Class.instance_method(:name).bind_call(klass)]] += 1
  end
  result[:sites] = sites.sort_by { |key, count| [-count, key.to_s] }.map do |(path, line, klass), count|
    {path: path, line: line, class: klass, objects: count, per_request: count.fdiv(20)}
  end
  result[:attributed_objects] = sites.values.sum
  result[:unattributed_objects] = result.fetch(:gc_allocated_objects) - sites.values.sum
  ObjectSpace.trace_object_allocations_clear
  GC.enable
else
  require_relative "../heap_windows"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  require ENV.fetch("HOTSPOT_EXTENSION") if mode == "profile"
  50.times { request.call }
  result[:warmup] = 50
  n = Integer(ENV.fetch("CENSUS_N", "20"))
  # Two within-process zero/full replicates. This is source attribution, not
  # an optimization/A/A price or a corpus-support certificate.
  windows = HeapWindows.windows(n).first(2) + HeapWindows.windows(n).first(2)
  windows.each { _1[:mode] = "total" }
  index = 0
  anchors = HeapWindows.run(windows, settle: -> { request.call }) do |count|
    if mode == "profile"
      HotspotProbe.measure(index, 41231 + index * 1_000_003) { count.times { request.call } }
    else
      count.times { request.call }
    end
    index += 1
  end
  result[:requests] = n
  result[:windows] = windows
  result[:heap_anchors] = anchors
  if mode == "profile"
    result[:profile] = HotspotProbe.results.fetch("windows")
    result[:details] = HotspotProbe.details
    result[:details]["frames"].each { _1[0] = normalize.call(_1[0]) }
  end
end
result[:response_bytes] = response_bytes
File.write(output, JSON.pretty_generate(result), perm: 0o600)
puts JSON.generate(result.except(:sites, :compiled_templates, :details, :windows))
