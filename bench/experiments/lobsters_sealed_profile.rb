# frozen_string_literal: true

# Off-only discovery, not an instruction price or removable-work claim.
# Run from the repository root with the committed Lobsters dependency overlay.
require "bundler/setup"
require "json"
require "digest"
require "stackprof"
require_relative "lobsters_sealed_screen"

app, state, destination = ARGV.map { File.expand_path(_1) }
abort "usage: lobsters_sealed_profile.rb APP SEED NEW_JSON" unless destination && !File.exist?(destination)
abort "Lowrail must be off" unless ENV["LOWRAIL"] == "0"
require File.join(app, "config/environment")
Exploration.install(config: {"app" => app}, state: state, arm: "off_a")
require "rack/mock"
rack = Rack::MockRequest.new(Rails.application)
report = {"scope" => "off-only sampled self CPU/allocation discovery; not removable shares or live traffic",
  "ruby" => RUBY_DESCRIPTION, "rails" => Rails.version, "stackprof" => StackProf::VERSION,
  "yjit" => RubyVM::YJIT.enabled?, "database" => ActiveRecord::Base.connection_db_config.database,
  "source_sha256" => BlogProduction::Entropy.source_pin(app),
  "database_sha256" => Digest::SHA256.file(File.join(state, "primary.sqlite3")).hexdigest,
  "script_sha256" => Digest::SHA256.file(__FILE__).hexdigest, "routes" => {}}
raise "fixture must remain in memory" unless report.fetch("database") == ":memory:"

%w[/ /s/enr7ye].each do |path|
  request = -> do
    response = rack.get(path, "HTTPS" => "on", "HTTP_HOST" => "localhost")
    raise "HTTP #{response.status}" unless response.status == 200
    response
  end
  500.times { request.call }
  operations = Hash.new(0)
  trace = TracePoint.new(:call) do |event|
    case event.method_id
    when :link_to, :form_with, :form_for, :token_tag, :collection_with_template, :_load_from_sql
      operations[event.method_id.to_s] += 1
    end
  end
  trace.enable { 3.times { request.call } }
  profiles = {"cpu" => [300, 1000], "object" => [20, 1]}.to_h do |mode, (n, interval)|
    profile = StackProf.run(mode: mode.to_sym, interval: interval) { n.times { request.call } }
    frames = profile.fetch(:frames).values.map do |frame|
      frame.slice(:name, :file, :line, :samples, :total_samples)
    end.sort_by { -_1.fetch(:samples) }
    [mode, {"requests" => n, "interval" => interval, "samples" => profile.fetch(:samples),
      "gc_samples" => profile.fetch(:gc_samples), "missed_samples" => profile.fetch(:missed_samples),
      "frame_self_sum" => frames.sum { _1.fetch(:samples) }, "frames" => frames}]
  end
  report.fetch("routes")["GET #{path}"] = {"operation_requests" => 3,
    "operations" => operations, "profiles" => profiles}
end
raise "app source changed" unless report.fetch("source_sha256") == BlogProduction::Entropy.source_pin(app)
File.write(destination, JSON.pretty_generate(report), perm: 0o600)
