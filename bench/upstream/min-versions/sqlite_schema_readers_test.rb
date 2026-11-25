# frozen_string_literal: true

# The SQLite schema readers on a plain connection, for script/min-versions. Active Record's own test helper calls
# table_exists?, which needs pragma_table_list (SQLite 3.37), so Rails' tests cannot boot at the 3.35 floor.
require "minitest/autorun"
require "active_record"

class SQLiteSchemaReadersTest < Minitest::Test
  def setup
    skip "SQLite only" unless ENV.fetch("ARCONN", "sqlite3") == "sqlite3"
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    @conn = ActiveRecord::Base.lease_connection
    @conn.execute 'CREATE TABLE "targets" ("id" INTEGER PRIMARY KEY)'
    @conn.execute 'CREATE TABLE "Widgets" ("id" INTEGER PRIMARY KEY, "ref" integer, CONSTRAINT widget_check CHECK (id > 0), ' \
      'CONSTRAINT "widget_fk" FOREIGN KEY ("ref") REFERENCES "targets" ("id"))'
    @conn.execute 'CREATE INDEX widget_idx ON "Widgets" ("ref")'
    @conn.execute 'CREATE VIEW "WidgetView" AS SELECT ref FROM "Widgets"'
  end

  def teardown
    ActiveRecord::Base.remove_connection
  end

  def test_columns
    assert_equal %w[id ref], @conn.columns("Widgets").map(&:name)
  end

  def test_primary_keys
    assert_equal %w[id], @conn.primary_keys("Widgets")
  end

  def test_indexes
    assert_equal [["widget_idx", %w[ref]]], @conn.indexes("Widgets").map { [_1.name, _1.columns] }
  end

  def test_foreign_keys
    assert_equal [["widget_fk", "targets"]], @conn.foreign_keys("Widgets").map { [_1.name, _1.to_table] }
  end

  def test_check_constraints
    assert_equal %w[widget_check], @conn.check_constraints("Widgets").map(&:name)
  end

  def test_view_columns
    assert_equal %w[ref], @conn.columns("WidgetView").map(&:name)
  end
end
