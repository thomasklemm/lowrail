# frozen_string_literal: true

# Run a clean Rails source tree or the two-line draft through genuine PG results.
require "json"
require "digest"
rails = File.realpath(ENV.fetch("RAILS_SOURCE"))
%w[activesupport activemodel activerecord].reverse_each { $LOAD_PATH.unshift(File.join(rails, _1, "lib")) }
require "active_record"
require "active_record/connection_adapters/postgresql_adapter"

module WorkloadPG
  module_function

  def shape(value)
    case value
    when String then [value.class.name, value.encoding.name, value.unpack1("H*"), value.frozen?]
    when Array then [value.class.name, value.frozen?, value.map { shape(_1) }]
    when Hash then value.map { |key, item| [shape(key), shape(item)] }
    when NilClass, TrueClass, FalseClass, Integer, Float then value
    else [value.class.name, value.to_s]
    end
  end

  def snapshot(adapter, sql)
    result = adapter.exec_query(sql)
    { columns: shape(result.columns), rows: shape(result.rows), cast_values: shape(result.cast_values),
      affected_rows: result.affected_rows, types: result.column_types.transform_values { _1.class.name } }
  rescue => error
    { error: error.class.name, message: error.message.lines.first.strip }
  end

  def cast_batch(adapter, results)
    results.each { |result| adapter.send(:cast_result, result) }
  end

  def stats
    if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
      RubyVM::ZJIT.stats
    elsif RubyVM::YJIT.enabled?
      RubyVM::YJIT.runtime_stats
    else
      {}
    end
  end
end

command, output = ARGV
raise "fresh output required" if File.exist?(output)
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "lowrail_corpus_u3_pg", host: "/var/run/postgresql")
adapter = ActiveRecord::Base.lease_connection
raw = adapter.raw_connection
raw.exec("CREATE TEMP TABLE u3_rows (id integer PRIMARY KEY, label text)")
raw.exec("INSERT INTO u3_rows VALUES (7, 'Tallinn Ω'), (19, 'second')")
if command == "controls"
  sqls = [
    "SELECT 7::integer AS n, 'Tallinn Ω'::text AS \"Nimi Ω\", NULL::text AS missing",
    "SELECT 7::integer AS n, 'Tallinn Ω'::text AS label WHERE false",
    "SELECT ARRAY[7,19]::integer[] AS list, '{\"key\":[7,19]}'::jsonb AS document, decode('00ff','hex') AS bytes",
    "SELECT 1.25::numeric AS decimal, '2026-10-22'::date AS day, '2026-10-22 12:34:56.125+03'::timestamptz AS instant",
    "SELECT 7 AS duplicate, 19 AS duplicate",
    "UPDATE u3_rows SET label = 'changed' WHERE id = 7",
    "UPDATE u3_rows SET label = 'returned Ω' WHERE id = 19 RETURNING id, label",
    "DELETE FROM u3_rows WHERE id = 999 RETURNING id, label",
    "SELECT * FROM u3_nonexistent_table"
  ]
  snapshots = sqls.map { WorkloadPG.snapshot(adapter, _1) }
  raise "unexpected query failure" unless snapshots.take(8).none? { _1.key?(:error) }
  raise "missing SQL error" unless snapshots.last[:error] == "ActiveRecord::StatementInvalid"
  first = adapter.exec_query("SELECT 'first Ω'::text AS value")
  second = adapter.exec_query("SELECT 'first Ω'::text AS value")
  raise "result arrays alias" if first.columns.equal?(second.columns) || first.rows.equal?(second.rows) || first.rows.first.equal?(second.rows.first)
  first.rows.first[0].replace("caller mutation")
  raise "result data aliases" unless second.rows == [["first Ω"]]
  class WorkloadPGRecord < ActiveRecord::Base
    self.table_name = "u3_rows"
  end
  class WorkloadPGSubclass < WorkloadPGRecord; end
  raise "subclass query lost" unless WorkloadPGSubclass.find(19).label == "returned Ω"
  states = %i[normal frozen cleared symbol_fields].map do |state|
    result = raw.exec("SELECT 7 AS n, 'Ω'::text AS label")
    result.freeze if state == :frozen
    result.clear if state == :cleared
    result.field_name_type = :symbol if state == :symbol_fields
    begin
      cast = adapter.send(:cast_result, result)
      [state, WorkloadPG.shape(cast.columns), WorkloadPG.shape(cast.rows), result.cleared?]
    rescue FrozenError => error
      # Inspect the actual receiver, not its process-specific address in inspect.
      [state, error.class.name, error.receiver.equal?(result), result.result_status, result.ntuples, result.nfields, result.cleared?]
    rescue => error
      [state, error.class.name, error.message]
    end
  end
  result = { snapshots: snapshots, ownership: "independent columns, rows, nested rows and mutable cells", subclass: true, pg_states: states }
elsif command == "measure"
  cases = {
    "no_columns_control" => "SET application_name = 'u3'",
    "zero_rows" => "SELECT 7 AS n, 'Ω'::text AS label WHERE false",
    "one_column" => "SELECT 7 AS n",
    "wide_32_columns" => "SELECT " + 32.times.map { "#{_1 + 7} AS c#{_1}" }.join(", "),
    "unicode_binary_null" => "SELECT 'Ω'::text AS \"Nimi Ω\", decode('00ff','hex') AS bytes, NULL::text AS missing"
  }
  measurements = cases.map do |label, sql|
    3.times { WorkloadPG.cast_batch(adapter, Array.new(1_000) { raw.exec(sql) }) }
    allocated_results = Array.new(2_000) { raw.exec(sql) }
    GC.start
    before = GC.stat(:total_allocated_objects)
    WorkloadPG.cast_batch(adapter, allocated_results)
    objects = (GC.stat(:total_allocated_objects) - before).fdiv(allocated_results.size)
    timed_results = Array.new(10_000) { raw.exec(sql) }
    GC.start
    jit_before = WorkloadPG.stats
    start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    WorkloadPG.cast_batch(adapter, timed_results)
    elapsed = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - start
    jit_after = WorkloadPG.stats
    deltas = jit_after.filter_map { |key, value| [key, value - jit_before.fetch(key, 0)] if value.is_a?(Numeric) && value != jit_before.fetch(key, 0) }.to_h
    { case: label, objects: objects, seconds_per_operation: elapsed / timed_results.size, jit_deltas: deltas }
  end
  source = File.join(rails, "activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb")
  result = { ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, zjit: defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?,
    pg: PG::VERSION, rails: ActiveRecord.version.to_s,
    source_sha256: Digest::SHA256.file(source).hexdigest, measurements: measurements }
else
  abort "usage: workload_pg.rb controls|measure NEW_JSON (RAILS_SOURCE required)"
end
File.write(output, JSON.pretty_generate(result) + "\n")
puts JSON.generate(result)
