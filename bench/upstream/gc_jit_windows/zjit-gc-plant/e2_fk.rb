# E2's scalar foreign_keys cohort as an upstream-bench script: the paired.rb fixture (1,000 tables with a foreign key
# and an index, 100 plain tables) in :memory: SQLite, one table per call in turn.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
c = ActiveRecord::Base.lease_connection
c.transaction do
  1000.times do |i|
    c.execute %(CREATE TABLE "t#{i}" ("id" integer PRIMARY KEY, "name" text COLLATE "NOCASE", "parent_id" integer, "noidx" integer, CONSTRAINT "fk_t#{i}" FOREIGN KEY ("parent_id") REFERENCES "t#{i}" ("id")))
    c.execute %(CREATE INDEX "index_t#{i}_on_parent_id" ON "t#{i}" ("parent_id"))
  end
  100.times { |i| c.execute %(CREATE TABLE "u#{i}" ("id" integer PRIMARY KEY, "value" integer)) }
end
tables = 1000.times.map { "t#{_1}" }
raise unless c.foreign_keys("t500").map(&:name) == ["fk_t500"]

i = 0
UpstreamBench.report("foreign_keys(t)") { c.foreign_keys(tables[(i += 1) % 1000]) }
