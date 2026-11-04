# Locks held by disable_referential_integrity on PostgreSQL 18.4+, and what
# happens when parallel test workers reset their databases at the same time.
# Needs a PostgreSQL 18.4+ server with default settings
# (max_locks_per_transaction = 64, max_connections = 100).
#   RAILS=/path/to/rails ruby fk_locks.rb   # env: FKS=300 WORKERS=24 PGPORT=5419
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { $LOAD_PATH.unshift(File.join(rails, _1, "lib")) }
require "active_record"

FKS = Integer(ENV.fetch("FKS", "300"))
WORKERS = Integer(ENV.fetch("WORKERS", "24"))
config = { adapter: "postgresql", host: "127.0.0.1", port: Integer(ENV.fetch("PGPORT", "5419")),
           username: ENV.fetch("PGUSER", "postgres") }
ActiveRecord::Base.establish_connection(config.merge(database: "postgres"))
WORKERS.times do |i|
  ActiveRecord::Base.connection.drop_database("fk_locks_#{i}")
  ActiveRecord::Base.connection.create_database("fk_locks_#{i}")
end
WORKERS.times do |i|
  ActiveRecord::Base.establish_connection(config.merge(database: "fk_locks_#{i}"))
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

c = ActiveRecord::Base.connection
held = ->(&work) { c.transaction { work.call; c.select_value("SELECT count(*) FROM pg_locks WHERE pid = pg_backend_pid()").tap { raise ActiveRecord::Rollback } } }
puts "Rails #{ActiveRecord.version}, PostgreSQL #{c.database_version}, #{FKS} foreign keys, #{c.tables.size} tables"
puts "locks held by one disable_referential_integrity: #{c.transaction { c.disable_referential_integrity { }; c.select_value("SELECT count(*) FROM pg_locks WHERE pid = pg_backend_pid()") }}"

# Parallel test workers reset and load fixtures in their own databases at the
# same time. Fixture loading keeps the toggle's locks until its transaction
# commits; the half-second sleep stands in for inserting the fixtures.
ActiveRecord::Base.connection_handler.clear_all_connections!
go_r, go_w = IO.pipe
reader, writer = IO.pipe
pids = WORKERS.times.map do |i|
  fork do
    go_w.close
    ActiveRecord::Base.establish_connection(config.merge(database: "fk_locks_#{i}"))
    conn = ActiveRecord::Base.connection
    tables = conn.tables
    go_r.read
    result = begin
      conn.transaction do
        conn.disable_referential_integrity { conn.truncate_tables(*tables) }
        sleep 0.5
      end
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
puts "#{WORKERS} workers at once: #{reader.read.lines.map(&:strip).tally}"
