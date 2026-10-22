# frozen_string_literal: true

# Off-only caller-line census. Not a timed cohort or a specialization variant.
require "bundler/setup"
require "json"
require "digest"
require "objspace"
require_relative "lobsters_sealed_screen"

app, state, destination = ARGV.map { File.expand_path(_1) }
abort "usage: lobsters_allocation_sites.rb APP SEED NEW_JSON" unless destination && !File.exist?(destination)
abort "Lowrail must be off" unless ENV["LOWRAIL"] == "0"
require File.join(app, "config/environment")
Exploration.install(config: {"app" => app}, state: state, arm: "off_a")
require "rack/mock"
rack = Rack::MockRequest.new(Rails.application)
headers = {"HTTPS" => "on", "HTTP_HOST" => "localhost", "HTTP_X_REQUEST_ID" => "lowrail-lobsters-sealed"}
report = {"scope" => "off-only caller-line allocation census; GC disabled, no timing or removable-share claim",
  "ruby" => RUBY_DESCRIPTION, "rails" => Rails.version, "database" => ActiveRecord::Base.connection_db_config.database,
  "source_sha256" => BlogProduction::Entropy.source_pin(app),
  "database_sha256" => Digest::SHA256.file(File.join(state, "primary.sqlite3")).hexdigest,
  "script_sha256" => Digest::SHA256.file(__FILE__).hexdigest, "headers" => headers, "routes" => {}}
raise "fixture must remain in memory" unless report.fetch("database") == ":memory:"

%w[/ /s/enr7ye].each do |path|
  request = -> do
    response = rack.get(path, headers)
    raise "HTTP #{response.status}" unless response.status == 200
    response
  end
  500.times { request.call }
  GC.start
  previously_disabled = GC.disable
  begin
    ObjectSpace.trace_object_allocations_start
    before = GC.stat(:total_allocated_objects)
    10.times { request.call }
    allocated = GC.stat(:total_allocated_objects) - before
    ObjectSpace.trace_object_allocations_stop
    counts = Hash.new(0)
    ObjectSpace.each_object do |object|
      file = ObjectSpace.allocation_sourcefile(object)
      next unless file
      line = ObjectSpace.allocation_sourceline(object)
      type = Object.instance_method(:class).bind_call(object)
      name = Class.instance_method(:name).bind_call(type) || "(anonymous)"
      counts[[file, line, name]] += 1
    end
    sites = counts.map do |(file, line, type), count|
      group = case file
      when %r{/(?:active_record|active_model)/} then "AR/model (including instantiation)"
      when %r{/action_dispatch/(?:routing|journey)/|/action_dispatch/http/url\.rb|/action_view/routing_url_for\.rb}
        "Routing/URL"
      when %r{/action_view/|/app/(?:views|helpers)/|/active_support/core_ext/erb/|/gems/(?:erb|erubi)-}
        "Views/helpers"
      when %r{/gems/rack-|/action_dispatch/(?:middleware|http)/} then "Rack/HTTP"
      else "Other"
      end
      {"group" => group, "file" => file.sub(app, "APP").sub(Gem.dir, "GEMS"),
        "line" => line, "class" => type, "objects" => count, "objects_per_request" => count.fdiv(10)}
    end.sort_by { -_1.fetch("objects") }
    report.fetch("routes")["GET #{path}"] = {"requests" => 10, "gc_allocated_objects" => allocated,
      "attributed_objects" => sites.sum { _1.fetch("objects") }, "sites" => sites}
  ensure
    ObjectSpace.trace_object_allocations_stop
    ObjectSpace.trace_object_allocations_clear
    GC.enable unless previously_disabled
  end
end
raise "app source changed" unless report.fetch("source_sha256") == BlogProduction::Entropy.source_pin(app)
File.write(destination, JSON.pretty_generate(report), perm: 0o600)
