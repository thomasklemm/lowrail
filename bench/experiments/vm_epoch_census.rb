# frozen_string_literal: true

# Run from an isolated corpus app with the census-instrumented Ruby.
# RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 ruby THIS_FILE /articles
# This is an untimed census, not a request-performance or support claim.
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"

abort "production required" unless Rails.env.production?
tokens_mode = ENV["CENSUS_TOKENS"] == "1"
abort "census build required" unless tokens_mode || RubyVM.respond_to?(:epoch_census_start)
abort "Lowrail must be off" if defined?(Lowrail)
Rails.application.eager_load!
Rails.logger.level = :fatal
ActiveRecord::Base.logger = nil
require ENV.fetch("CENSUS_SETUP") if ENV["CENSUS_SETUP"]
session = Rack::MockRequest.new(Rails.application)
headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on"}.merge(JSON.parse(ENV.fetch("CENSUS_HEADERS", "{}")))
warmup = Integer(ENV.fetch("CENSUS_WARMUP", "200"))
count = Integer(ENV.fetch("CENSUS_REQUESTS", "1000"))
rows = ARGV.map do |path|
  request = -> do
    response = session.get(path, headers)
    raise "#{path}: #{response.status}" unless response.status == 200
    raise "empty response" if response.body.empty?
    response
  end
  warmup.times { request.call }
  token_specs = if tokens_mode
    view = ApplicationController.new.view_context
    builder = view.send(:tag_builder)
    [[Hash, :each], [Hash, :each_with_object]] +
      %i[convert_options_to_data_attributes link_to_remote_options? url_target url_for content_tag ensure_valid_html5_tag_name tag_builder].map { [view.class, _1] } +
      %i[content_tag_string tag_options tag_option].map { [builder.class, _1] }
  else
    []
  end
  held = token_specs.map { |klass, name| RubyVM.method_token(klass, name) }
  raise "unsupported method dependency" if held.any?(&:nil?)
  token_invalidations = Hash.new(0)
  token_deltas = Array.new(count, 0)
  deltas = Array.new(count)
  non_singleton = Array.new(count)
  statuses = Hash.new(0)
  RubyVM.epoch_census_start unless tokens_mode
  count.times do |i|
    before = RubyVM.mutation_epoch
    ns_before = RubyVM.non_singleton_epoch unless tokens_mode
    response = request.call
    deltas[i] = RubyVM.mutation_epoch - before
    non_singleton[i] = RubyVM.non_singleton_epoch - ns_before unless tokens_mode
    held.each_with_index do |token, index|
      next if token.valid?
      klass, name = token_specs.fetch(index)
      token_invalidations["#{klass}##{name}"] += 1
      token_deltas[i] += 1
      held[index] = RubyVM.method_token(klass, name)
      raise "dependency disappeared" unless held[index]
    end
    statuses[response.status] += 1
  end
  seams = RubyVM.epoch_census_stop unless tokens_mode
  {path: path, warmup: warmup, requests: count, statuses: statuses,
    changed_requests: deltas.count(&:positive?), bumps: deltas.sum, histogram: deltas.tally,
    non_singleton_changed_requests: tokens_mode ? nil : non_singleton.count(&:positive?),
    non_singleton_bumps: tokens_mode ? nil : non_singleton.sum, non_singleton_histogram: tokens_mode ? nil : non_singleton.tally,
    seams: seams, held_tokens: token_specs.map { |klass, name| "#{klass}##{name}" },
    token_changed_requests: token_deltas.count(&:positive?), token_invalidations: token_invalidations,
    token_invalidation_histogram: token_deltas.tally}
end
puts "EPOCH_CENSUS #{JSON.generate(ruby: RUBY_DESCRIPTION, rails: Rails.version,
  yjit: RubyVM::YJIT.enabled?, app: Dir.pwd, rows: rows)}"
