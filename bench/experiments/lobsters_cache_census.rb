# frozen_string_literal: true

# Off-only diagnostic. No cache/config/application optimization is installed.
require "bundler/setup"
require "json"
require "digest"
require "objspace"
require_relative "lobsters_sealed_screen"

app, state, destination = ARGV.map { File.expand_path(_1) }
abort "usage: lobsters_cache_census.rb APP SEED NEW_JSON" unless destination && !File.exist?(destination)
abort "Lowrail must be off" unless ENV["LOWRAIL"] == "0"
require File.join(app, "config/environment")
Exploration.install(config: {"app" => app}, state: state, arm: "off_a")
require "rack/mock"

module CacheCensus
  class << self
    attr_accessor :active, :key, :records, :load_arguments

    def graph(root, allocated)
      seen = {}.compare_by_identity
      pending = [root]
      until pending.empty?
        object = pending.pop
        next unless allocated.key?(object) && !seen.key?(object)
        seen[object] = true
        ObjectSpace.reachable_objects_from(object)&.each do |child|
          pending << child if allocated.key?(child)
        end
      end
      seen
    end

    def rows(objects, retained)
      counts = Hash.new(0)
      objects.each do |object, site|
        counts[[*site, retained.key?(object) ? "result_graph" : "intermediate"]] += 1
      end
      counts.map do |(file, line, klass, role), count|
        {file: file, line: line, class: klass, role: role, objects: count}
      end.sort_by { [-_1[:objects], _1[:file], _1[:class]] }
    end
  end

  module Fetch
    def fetch(name, ...)
      previous = CacheCensus.key
      CacheCensus.key = name if CacheCensus.active
      super
    ensure
      CacheCensus.key = previous
    end
  end

  module NativeLoad
    def _load(string)
      CacheCensus.load_arguments[string] = name if CacheCensus.active
      super
    end
  end

  module Load
    def load(source, ...)
      return super unless CacheCensus.active
      callers = caller_locations.map { {file: _1.path, line: _1.lineno, label: _1.label} }
      CacheCensus.load_arguments = {}.compare_by_identity
      ObjectSpace.trace_object_allocations_start
      result = super
      ObjectSpace.trace_object_allocations_stop
      allocated = {}.compare_by_identity
      ObjectSpace.each_object do |object|
        file = ObjectSpace.allocation_sourcefile(object)
        next unless file
        allocated[object] = [file, ObjectSpace.allocation_sourceline(object), object.class.name]
      end
      retained = CacheCensus.graph(result, allocated)
      strings = Hash.new(0)
      allocated.each do |object, site|
        next unless site.first == "<internal:marshal>" && object.instance_of?(String) && !retained.key?(object)
        fallback = ENV["CACHE_CENSUS_NATIVE_ARGS"] == "1" ? "metadata/key/symbol names" : "unclassified (native observer off)"
        strings[CacheCensus.load_arguments[object] || fallback] += 1
      end
      CacheCensus.records << {
        key: CacheCensus.key, callers: callers, result_class: result.class.name,
        result_array_size: (result.size if result.instance_of?(Array)),
        result_shape: result.map { |item| {class: item.class.name, size: (item.size if item.instance_of?(Array))} },
        payload_bytes: source.bytesize, payload_sha256: Digest::SHA256.hexdigest(source),
        intermediate_string_roles: strings,
        rows: CacheCensus.rows(allocated, retained)
      }
      result
    ensure
      if CacheCensus.active
        ObjectSpace.trace_object_allocations_stop
        ObjectSpace.trace_object_allocations_clear
      end
    end
  end
end

ActiveSupport::Cache::Store.prepend(CacheCensus::Fetch)
Marshal.singleton_class.prepend(CacheCensus::Load)
if ENV["CACHE_CENSUS_NATIVE_ARGS"] == "1"
  Time.singleton_class.prepend(CacheCensus::NativeLoad)
  BigDecimal.singleton_class.prepend(CacheCensus::NativeLoad)
end
rack = Rack::MockRequest.new(Rails.application)
headers = {"HTTPS" => "on", "HTTP_HOST" => "localhost", "HTTP_X_REQUEST_ID" => "lowrail-lobsters-sealed"}
report = {ruby: RUBY_DESCRIPTION, rails: Rails.version, store: Rails.cache.class.name,
  coder: Rails.cache.instance_variable_get(:@coder).class.name,
  native_args_observer: ENV["CACHE_CENSUS_NATIVE_ARGS"] == "1",
  cache_format: ActiveSupport::Cache.format_version, ar_format: ActiveRecord.marshalling_format_version,
  database: ActiveRecord::Base.connection_db_config.database,
  database_sha256: Digest::SHA256.file(File.join(state, "primary.sqlite3")).hexdigest,
  source_sha256: BlogProduction::Entropy.source_pin(app), routes: {}}
raise "fixture must remain in memory" unless report[:database] == ":memory:"
%w[/ /s/enr7ye].each do |path|
  request = -> { rack.get(path, headers).tap { raise "HTTP #{_1.status}" unless _1.status == 200 } }
  500.times { request.call }
  GC.start
  previously_disabled = GC.disable
  begin
    CacheCensus.records = []
    CacheCensus.active = true
    3.times { request.call }
    CacheCensus.active = false
    report[:routes][path] = CacheCensus.records
  ensure
    CacheCensus.active = false
    GC.enable unless previously_disabled
  end
end
raise "app source changed" unless report[:source_sha256] == BlogProduction::Entropy.source_pin(app)
File.write(destination, JSON.pretty_generate(report), perm: 0o600)
