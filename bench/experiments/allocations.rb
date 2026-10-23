# frozen_string_literal: true

# Measurement only. Run from a prepared corpus app, with LOWRAIL=0 or with
# RUBYOPT='-I/abs/lowrail/gem/lib -rlowrail/setup' LOWRAIL=1. Headers stay private.
# ALLOC_OUT=/tmp/new.json ALLOC_ROUTE=/articles ruby --yjit /abs/allocations.rb
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false unless ENV.fetch("BENCH_JIT", "1") == "1"
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "objspace"
require "json"
require "digest"

Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
raise "expected Rails 8.1.4" unless Rails.version == "8.1.4"
raise "unexpected JIT" unless !!RubyVM::YJIT.enabled? == (ENV.fetch("BENCH_JIT", "1") == "1")
raise "off worker loaded Lowrail" if ENV["LOWRAIL"] == "0" && defined?(Lowrail)
session = Rack::MockRequest.new(Rails.application)
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.
  merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
route = ENV.fetch("ALLOC_ROUTE")
request = -> {
  response = session.get(route, headers)
  raise "HTTP #{response.status}" unless response.status == 200
  nil # Never retain the last response on behalf of the profiler.
}
if ENV["ALLOC_SSR"] == "1"
  root = Nokogiri::HTML(session.get(route, headers).body).at_css("#app")
  raise "missing SSR markup" unless root&.element_children&.any?
  root = nil
end
Integer(ENV.fetch("BENCH_WARMUP", "400")).times { request.call }

# Production-like total: tracing off, ordinary GC enabled. Not timing evidence.
n = Integer(ENV.fetch("ALLOC_TOTAL_REQUESTS", "100"))
totals = 3.times.map do
  3.times { GC.start }
  before = GC.stat
  n.times { request.call }
  after = GC.stat
  %i[total_allocated_objects minor_gc_count major_gc_count].to_h { [_1, after[_1] - before[_1]] }
end

# Bounded census: no collection can erase an allocation before enumeration.
# ObjectSpace cannot enumerate VM-internal IMEMOs; the GC.stat residual is
# explicit, not silently assigned to a user-visible class or callsite.
n = Integer(ENV.fetch("ALLOC_REQUESTS", "20"))
normalize = ->(file) {
  next "<no Ruby source>" unless file
  file.sub(Rails.root.to_s + "/", "APP/").
    sub(%r{\A.*/gems/}, "GEM/").
    sub(RbConfig::CONFIG.fetch("rubylibdir") + "/", "RUBY/").
    sub(File.expand_path("../..", __dir__) + "/", "LOWRAIL/")
}
require_relative "../allocation_census"
census = AllocationCensus.capture(n, normalize: normalize, &request)
result = { ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?, rails: Rails.version,
  lowrail: ENV.fetch("LOWRAIL"), route: route, requests: n, warmup: Integer(ENV.fetch("BENCH_WARMUP", "400")),
  total_requests_per_block: Integer(ENV.fetch("ALLOC_TOTAL_REQUESTS", "100")), totals: totals,
  **census,
  lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest,
  runtime_sha256: Dir[File.expand_path("../../gem/lib/**/*.rb", __dir__)].sort.to_h {
    [_1.split("/gem/lib/").last, Digest::SHA256.file(_1).hexdigest] },
  manifest_sha256: File.exist?(".lowrail/manifest.json") ? Digest::SHA256.file(".lowrail/manifest.json").hexdigest : nil }
File.write(ENV.fetch("ALLOC_OUT"), JSON.pretty_generate(result), perm: 0o600)
puts JSON.generate(result.except(:callsites, :runtime_sha256))
