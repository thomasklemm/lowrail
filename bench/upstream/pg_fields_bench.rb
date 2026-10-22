# frozen_string_literal: true

# Standalone public allocation benchmark; Ruby 4.0.7 and PostgreSQL 15 used.
# No Rails application, Lowrail checkout, app fixtures or persistent writes.
# Save this file anywhere, then prepare the public sources/dependencies:
#
#   gem install activerecord -v 8.1.4 --no-document
#   gem install pg -v 1.6.3 --no-document
#   git clone https://github.com/rails/rails.git rails-fields
#   git -C rails-fields fetch https://github.com/thomasklemm/rails.git thomasklemm/reuse-postgresql-result-fields
#   git -C rails-fields worktree add --detach ../rails-fields-off 7e3828a6b573cfda08ad9985060bcaaf76358826
#   git -C rails-fields worktree add --detach ../rails-fields-on 220c4f2387290038dccb4d93e4e6b0bf81bc196a
#   createdb lowrail_fields_bench
#   export BENCH_DATABASE_URL=postgresql:///lowrail_fields_bench
#   RAILS_SOURCE="$PWD/rails-fields-off" ruby pg_fields_bench.rb > off.json
#   RAILS_SOURCE="$PWD/rails-fields-on" ruby pg_fields_bench.rb > on.json
# Repeat both invocations with ruby --yjit (and --zjit on a supporting build).
# Compare objects_per_cast: column-bearing cases save one; no-columns stays
# unchanged. SQL, native PG result construction and explicit GC are outside
# each allocation window. This is not a latency, throughput or Ir benchmark.

require "json"
require "digest"
gem "pg", "1.6.3"
rails = File.realpath(ENV.fetch("RAILS_SOURCE"))
file = File.join(rails, "activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb")
sha = Digest::SHA256.file(file).hexdigest
raise "expected pinned Rails baseline or fork source" unless %w[
  f1fef05ce9b14ac25b5ff9c7b7285eb867c7ac2e32a0c5afe861893d2f0a9a4e
  afa0c671a26b7cbb5bae84709a192f308736dccf8b168d3c75801a85eee8221c
].include?(sha)
%w[activesupport activemodel activerecord].reverse_each { $LOAD_PATH.unshift(File.join(rails, _1, "lib")) }
require "active_record"
require "active_record/connection_adapters/postgresql_adapter"
ActiveRecord::Base.establish_connection(ENV.fetch("BENCH_DATABASE_URL"))
adapter = ActiveRecord::Base.lease_connection
raw = adapter.raw_connection

def cast_all(adapter, results)
  results.each { |result| adapter.send(:cast_result, result) }
end

cases = {
  "no_columns_control" => "SET application_name = 'public-fields-bench'",
  "zero_rows" => "SELECT 7 AS n, 'Ω'::text AS label WHERE false",
  "one_column" => "SELECT 7 AS n",
  "wide_32_columns" => "SELECT " + 32.times.map { "#{_1 + 7} AS c#{_1}" }.join(", "),
  "unicode_binary_null" => "SELECT 'Ω'::text AS \"Nimi Ω\", decode('00ff','hex') AS bytes, NULL::text AS missing"
}
measurements = cases.map do |label, sql|
  3.times { cast_all(adapter, Array.new(1000) { raw.exec(sql) }) }
  results = Array.new(2000) { raw.exec(sql) }
  GC.start
  before = GC.stat(:total_allocated_objects)
  cast_all(adapter, results)
  objects = (GC.stat(:total_allocated_objects) - before).fdiv(results.size)
  raise "cast did not clear native results" unless results.all?(&:cleared?)
  { case: label, operations: results.size, objects_per_cast: objects }
end
puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, pg: PG::VERSION, source_sha256: sha,
  yjit: RubyVM::YJIT.enabled?, zjit: !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?),
  scope: "allocations only; genuine PG results; no application data", measurements: measurements)
