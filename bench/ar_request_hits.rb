# frozen_string_literal: true

# Untimed, warmed request probe. Use the same production build, fixture headers,
# LOWRAIL_UNITS and response-cache settings as ar_cached_runs.rb. Output only
# public route labels and genuine completed plan executions, never credentials.
# From the app: ruby --yjit /abs/lowrail/bench/ar_request_hits.rb
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "LOWRAIL_STATS must be enabled" unless defined?(Lowrail::Stats) && Lowrail::Stats.enabled?

module ARRequestHits
  COUNTS = Hash.new(0)

  def execute(association, scope)
    result = super
    if result
      reflection = association.reflection
      COUNTS["#{reflection.active_record.name}##{reflection.name}"] += 1
    end
    result
  end
end
Lowrail::ARPlans::Plan.prepend(ARRequestHits) if defined?(Lowrail::ARPlans)

campfire = Rails.application.class.module_parent_name == "Campfire"
paths = JSON.parse(File.read("tmp/m0/paths.json"))
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(
  JSON.parse(File.read("tmp/m0/#{campfire ? 'headers.json' : 'headers-json.json'}")))
keys = campfire ? %w[room messages sidebar search] : %w[organizations contacts]
session = Rack::MockRequest.new(Rails.application)
rows = keys.map do |key|
  request = -> {
    response = session.get(paths.fetch(key), headers)
    raise "#{key} -> #{response.status}" unless response.status == 200
  }
  200.times { request.call }
  Lowrail::Stats.reset_counts!
  ARRequestHits::COUNTS.clear
  10.times { request.call }
  { route: key, requests: 10,
    hits_per_request: ARRequestHits::COUNTS.transform_values { _1.fdiv(10) },
    stats: { hits: Lowrail::Stats.unit_hits, fallbacks: Lowrail::Stats.unit_fallbacks } }
end
File.write(ENV.fetch("BENCH_JSON"), JSON.pretty_generate(rows))
puts JSON.pretty_generate(rows)
