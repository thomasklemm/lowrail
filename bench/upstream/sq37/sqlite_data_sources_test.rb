# frozen_string_literal: true

# Public Active Record APIs that list or look up tables and views, on a plain SQLite connection, for script/min-versions.
# data_source_sql reads pragma_table_list (SQLite 3.37.0) since Rails 8.0; check_version accepts older SQLite.
require "minitest/autorun"
require "stringio"
require "tmpdir"
require "active_record"

class SQLiteDataSourcesTest < Minitest::Test
  class Widget < ActiveRecord::Base; end

  def setup
    skip "SQLite only" unless ENV.fetch("ARCONN", "sqlite3") == "sqlite3"
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    @conn = ActiveRecord::Base.lease_connection
    @conn.execute 'CREATE TABLE "widgets" ("id" INTEGER PRIMARY KEY, "name" varchar)'
    @conn.execute 'CREATE VIEW "widget_names" AS SELECT name FROM "widgets"'
  end

  def teardown
    ActiveRecord::Base.remove_connection
  end

  def test_control_raw_sql
    @conn.execute "INSERT INTO widgets (name) VALUES ('a')"
    assert_equal "a", @conn.select_value("SELECT name FROM widget_names")
  end

  def test_control_columns
    assert_equal %w[id name], @conn.columns("widgets").map(&:name)
  end

  # The schema cache checks data_source_exists? before it reads a model's columns and primary key.
  def test_model_column_names
    assert_equal %w[id name], Widget.column_names
  end

  def test_model_create_and_find
    assert_equal "a", Widget.find(Widget.create!(name: "a").id).name
  end

  def test_table_exists
    assert @conn.table_exists?("widgets")
  end

  def test_data_source_exists
    assert @conn.data_source_exists?("widget_names")
  end

  def test_view_exists
    assert @conn.view_exists?("widget_names")
  end

  def test_data_sources
    assert_equal %w[widget_names widgets], @conn.data_sources.sort
  end

  def test_tables
    assert_equal %w[widgets], @conn.tables
  end

  def test_views
    assert_equal %w[widget_names], @conn.views
  end

  def test_model_table_exists
    assert Widget.table_exists?
  end

  def test_schema_cache_data_source_exists
    assert ActiveRecord::Base.schema_cache.data_source_exists?("widgets")
  end

  def test_create_table_force
    @conn.create_table(:gadgets, force: true) { _1.string :name }
    assert_includes @conn.columns("gadgets").map(&:name), "name"
  end

  def test_migrate_creates_schema_migrations
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "1_create_gizmos.rb"), <<~RUBY)
        class CreateGizmos < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]
          def change = create_table(:gizmos)
        end
      RUBY
      ActiveRecord::MigrationContext.new(dir).migrate
      assert_equal [1], ActiveRecord::Base.connection_pool.schema_migration.versions.map(&:to_i)
    end
  end

  def test_schema_dump
    assert_match 'create_table "widgets"', ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, StringIO.new).string
  end
end
