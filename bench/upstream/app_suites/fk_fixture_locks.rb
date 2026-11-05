# Parallel test workers starting at the same time on PostgreSQL 18.4+: each
# empties its own database and loads fixtures for every table, as a worker of a
# parallel suite does at its start. Counts `out of shared memory` failures.
# Needs a PostgreSQL 18.4+ server (max_locks_per_transaction = 64 by default).
#   RAILS=/path/to/rails SETUP=1 ruby fk_fixture_locks.rb   # env: FKS=300 WORKERS=8 ROUNDS=3 PGPORT=5419
# SETUP=1 (re)creates the databases; later runs reuse them.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { $LOAD_PATH.unshift(File.join(rails, _1, "lib")) }
require "active_record"

FKS = Integer(ENV.fetch("FKS", "300"))
WORKERS = Integer(ENV.fetch("WORKERS", "8"))
ROUNDS = Integer(ENV.fetch("ROUNDS", "3"))
config = { adapter: "postgresql", host: "127.0.0.1", port: Integer(ENV.fetch("PGPORT", "5419")),
           username: ENV.fetch("PGUSER", "postgres") }

if ENV["SETUP"]
  ActiveRecord::Base.establish_connection(config.merge(database: "postgres"))
  WORKERS.times do |i|
    ActiveRecord::Base.connection.drop_database("fk_fixture_locks_#{i}")
    ActiveRecord::Base.connection.create_database("fk_fixture_locks_#{i}")
  end
  WORKERS.times do |i|
    ActiveRecord::Base.establish_connection(config.merge(database: "fk_fixture_locks_#{i}"))
    c = ActiveRecord::Base.connection
    c.create_table(:parents)
    (FKS / 2).times do |t|
      c.create_table("children_#{t}") do |t|
        t.references :parent, foreign_key: true
        t.references :other, foreign_key: { to_table: :parents }
        t.string :name, index: true
      end
    end
  end
  ActiveRecord::Base.connection_handler.clear_all_connections!
end

fixtures = { "parents" => (1..5).map { { "id" => _1 } } }
(FKS / 2).times do |t|
  fixtures["children_#{t}"] = (1..5).map { |i| { "id" => i, "parent_id" => i, "other_id" => i, "name" => "x" } }
end

ActiveRecord::Base.establish_connection(config.merge(database: "fk_fixture_locks_0"))
c = ActiveRecord::Base.connection
held = lambda do |&work|
  count = nil
  c.transaction do
    work.call
    count = c.select_value("SELECT count(*) FROM pg_locks WHERE pid = pg_backend_pid()")
    raise ActiveRecord::Rollback
  end
  count
end
tables = c.tables
puts "Rails #{ActiveRecord.version}, PostgreSQL #{c.database_version}, max_locks_per_transaction #{c.select_value("SHOW max_locks_per_transaction")}, #{FKS} foreign keys, #{tables.size} tables"
puts "locks held by one disable_referential_integrity: #{held.call { c.disable_referential_integrity { } }}"
puts "locks held by one insert_fixtures_set for every table: #{held.call { c.insert_fixtures_set(fixtures, tables) }}"
ActiveRecord::Base.connection_handler.clear_all_connections!

results = Hash.new(0)
ROUNDS.times do
  go_r, go_w = IO.pipe
  reader, writer = IO.pipe
  pids = WORKERS.times.map do |i|
    fork do
      go_w.close
      ActiveRecord::Base.establish_connection(config.merge(database: "fk_fixture_locks_#{i}"))
      conn = ActiveRecord::Base.connection
      tables = conn.tables
      go_r.read
      result = begin
        conn.truncate_tables(*tables)
        conn.insert_fixtures_set(fixtures, tables)
        "ok"
      rescue => e
        e.message[/out of shared memory/] || e.class.name
      end
      writer.puts(result)
    end
  end
  go_w.close
  pids.each { Process.wait(_1) }
  writer.close
  reader.read.lines.each { results[_1.strip] += 1 }
end
puts "#{WORKERS} workers at once, #{ROUNDS} rounds: #{results}"
