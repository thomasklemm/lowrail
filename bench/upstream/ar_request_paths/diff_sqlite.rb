# Differential check for the SQLite3 perform_query change: prints every observable result; diff main vs candidate.
require "bundler/setup"
require "active_record"
require "digest"

out = []
log = ->(*a) { out << a.map(&:inspect).join(" ") }

calls = Hash.new(0)
module CountTypeMap
  def type_map(...) = (CountTypeMap.calls[:type_map] += 1; super)
  class << self; attr_accessor :calls; end
end
CountTypeMap.calls = Hash.new(0)

configs = [
  { prepared_statements: true },
  { prepared_statements: false },
  { prepared_statements: true, default_timezone: "local" },
  { prepared_statements: true, default_timezone: "utc" },
  { prepared_statements: true, statement_limit: 2 },
]

configs.each do |cfg|
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", **cfg)
  conn = ActiveRecord::Base.lease_connection
  log.(:config, cfg)
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Schema.define do
    create_table(:things, force: true) do |t|
      t.string :name; t.integer :n; t.decimal :d, precision: 8, scale: 2; t.float :f; t.boolean :b
      t.datetime :at; t.date :on; t.time :tm; t.binary :bin; t.text :tx; t.json :js; t.timestamps
    end
  end
  Object.send(:remove_const, :Thing) if defined?(Thing)
  Thing = Class.new(ActiveRecord::Base) { self.table_name = "things" }
  3.times do |i|
    Thing.create!(name: "n#{i}", n: i, d: "1.#{i}", f: i / 3.0, b: i.odd?, at: Time.utc(2026, 1, 2, 3, 4, i),
      on: Date.new(2026, 1, i + 1), tm: "10:0#{i}:00", bin: "\x00\xFF#{i}".b, tx: "t" * i, js: { "a" => i }, created_at: Time.utc(2026, 2, 1), updated_at: Time.utc(2026, 2, 1))
  end
  dump = ->(r) { [r.columns, r.rows, r.column_types.map { |k, v| [k, v.class.name, v.respond_to?(:precision) ? v.precision : nil] }] }
  sqls = [
    "SELECT * FROM things",
    "SELECT name, n, d FROM things WHERE n > ?",
    "SELECT count(*) AS c, max(at) AS m FROM things",
    "SELECT 1 AS one, 'x' AS s, 1.5 AS fl, NULL AS nl",
    "SELECT name FROM things WHERE 1 = 0",
    "SELECT things.*, upper(name) AS up FROM things ORDER BY id DESC",
  ]
  2.times do |round|
    sqls.each do |sql|
      binds = sql.include?("?") ? [ActiveRecord::Relation::QueryAttribute.new("n", 0, ActiveModel::Type::Integer.new)] : []
      r = conn.select_all(sql, "Q", binds, preparable: true)
      log.(round, sql, dump.(r))
    end
    log.(:records, Thing.order(:id).map { |t| t.attributes.transform_values { |v| v.is_a?(Time) ? [v.class, v.to_a, v.zone] : v } })
    log.(:find, Thing.find(1).attributes.keys, Thing.find_by(name: "n2")&.n, Thing.where(n: [0, 2]).pluck(:name, :d))
    log.(:dml, conn.exec_update("UPDATE things SET n = n + 1 WHERE id = 1"), Thing.find(2).update!(n: 5, updated_at: Time.utc(2026, 3, 1)), conn.exec_delete("DELETE FROM things WHERE id = 99"))
    log.(:pool, conn.instance_variable_get(:@statements).length)
  end
  # schema change between executions of the same prepared statement
  conn.add_column(:things, :extra, :integer, default: 7)
  Thing.reset_column_information
  log.(:after_add, dump.(conn.select_all("SELECT * FROM things", "Q", [], preparable: true)))
  conn.remove_column(:things, :tx)
  Thing.reset_column_information
  log.(:after_remove, dump.(conn.select_all("SELECT * FROM things", "Q", [], preparable: true)))
  begin
    conn.select_all("SELECT nope FROM things", "Q", [], preparable: true)
  rescue => e
    log.(:error, e.class, e.message[/no such column.*/])
  end
  log.(:pool_end, conn.instance_variable_get(:@statements).length)
  conn.disconnect!
end
ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(CountTypeMap)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
c = ActiveRecord::Base.lease_connection
c.select_all("SELECT 1 AS a, 2 AS b, 3 AS c")
puts out
puts "type_map calls for a 3-column result: #{CountTypeMap.calls[:type_map]}"
puts Digest::SHA256.hexdigest(out.join("\n"))
