# Usage: RAILS=/path/to/rails APM=otel|datadog|rmp ruby apm_pg_spans.rb
# Needs a local PostgreSQL with a "postgres" database. Counts the SQL spans (or records) that each APM gem's pg
# integration, and its Active Record integration where it has one, produces for four queries: a `where` without
# binds, a `create` (prepared INSERT), a prepared `find`, and a `where` with binds outside prepared statements.
require "bundler/inline"
APM = ENV.fetch("APM")
gemfile do
  source "https://rubygems.org"
  gem "activerecord", path: ENV.fetch("RAILS")
  gem "activesupport", path: ENV.fetch("RAILS")
  gem "activemodel", path: ENV.fetch("RAILS")
  gem "pg"
  case APM
  when "otel"
    gem "opentelemetry-sdk", "1.13.1"
    gem "opentelemetry-instrumentation-pg", "0.37.1"
    gem "opentelemetry-instrumentation-active_record", "0.13.0"
  when "datadog"
    gem "datadog", "2.48.0"
  when "rmp"
    gem "rack-mini-profiler", "5.0.0", require: false
  end
end
require "active_record"
require "logger"

SPANS = []
case APM
when "otel"
  require "opentelemetry/sdk"
  require "opentelemetry-instrumentation-pg"
  require "opentelemetry-instrumentation-active_record"
  EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  OpenTelemetry.logger = Logger.new(File::NULL)
  OpenTelemetry::SDK.configure do |c|
    c.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER))
    c.use "OpenTelemetry::Instrumentation::PG"
    c.use "OpenTelemetry::Instrumentation::ActiveRecord"
  end
  def collect = EXPORTER.finished_spans.map { |s| [s.instrumentation_scope.name.split("::").last, s.name] }
  def names = EXPORTER.finished_spans.map { |s| "#{s.instrumentation_scope.name.split("::").last}: #{s.name}" }
  def reset = EXPORTER.reset
when "datadog"
  require "datadog"
  Datadog.configure do |c|
    c.logger.instance = Logger.new(File::NULL)
    c.diagnostics.startup_logs.enabled = false
    c.telemetry.enabled = false
    c.remote.enabled = false
    c.tracing.instrument :pg
    c.tracing.instrument :active_record
    c.tracing.test_mode.enabled = true
  end
  # Drop every trace before it reaches the writer, after recording its spans.
  Datadog::Tracing.before_flush { |trace| trace.spans.each { |s| SPANS << [s.service.to_s, s.name] }; nil }
  def collect = SPANS.dup
  def names = SPANS.map { |a, b| "#{a}: #{b}" }
  def reset = SPANS.clear
when "rmp"
  # In a Rails app, SqlPatches picks "pg" itself and then turns off its Active Record subscription.
  ENV["RACK_MINI_PROFILER_PATCH"] = "pg"
  require "rack-mini-profiler"
  # Drive the pg patch without a request: measure always, and record what it reports.
  SqlPatches.singleton_class.prepend(Module.new { def should_measure? = true })
  Rack::MiniProfiler.singleton_class.prepend(Module.new { def record_sql(sql, *) = (SPANS << ["pg patch", sql[0, 40]]; RECORD) })
  RECORD = Object.new.tap { |r| def r.report_reader_duration(*) = nil }
  def collect = SPANS.dup
  def names = SPANS.map { |a, b| "#{a}: #{b}" }
  def reset = SPANS.clear
end

ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres", prepared_statements: true)
ActiveRecord::Base.lease_connection.execute("DROP TABLE IF EXISTS apm_posts; CREATE TABLE apm_posts (id bigserial primary key, title text)")
class ApmPost < ActiveRecord::Base; end

QUERIES = {
  "where (no binds)" => -> { ApmPost.where("title = 'x'").to_a },
  "create (prepared)" => -> { ApmPost.create!(title: "x") },
  "find (prepared)" => -> { ApmPost.find(1) },
  "where (binds, unprepared)" => -> { ApmPost.lease_connection.unprepared_statement { ApmPost.where(title: "x").to_a } },
}
QUERIES.each_value(&:call) # warm up: schema, prepared statements
puts "Rails #{ActiveRecord.version}, #{APM}"
QUERIES.each do |label, query|
  reset
  query.call
  spans = collect.group_by(&:first).transform_values(&:size)
  puts "  #{label}: #{spans.empty? ? "no spans" : spans}"
  puts "    #{names.uniq.join(" | ")}" if ENV["NAMES"]
end
