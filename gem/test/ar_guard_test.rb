# frozen_string_literal: true

require_relative "test_helper"

# Lowrail::AR.epoch against real Rails/SQLite: it must stay put under normal
# reads and writes (or plans never hit) and move for exactly the class, and
# its descendants, that a test changes.
class ARGuardTest < Minitest::Test
  include LowrailTest

  SCENARIO = <<~'RUBY'
    require "lowrail/ar_guard"
    Lowrail::AR.install # before Active Record is loaded, as under RUBYOPT
    gem "activerecord", "~> 8.1.4"
    require "active_record"
    require "json"
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table(:items) { |t| t.string :name; t.string :type; t.integer :state }
      create_table(:parts) { |t| t.integer :item_id }
      create_table(:others) { |t| t.string :name }
    end
    class Item < ActiveRecord::Base; end
    class Special < Item; end
    class Part < ActiveRecord::Base; end
    class Other < ActiveRecord::Base; end

    AR = Lowrail::AR
    out = { "hooked" => AR.installed? }
    epochs = -> { [Item, Special, Part, Other].to_h { [_1.name, AR.epoch(_1)] } }
    # Warm up: the first query loads each schema (an event).
    [Item, Special, Part, Other].each { _1.first; _1.new }
    before = epochs.()
    Item.create!(name: "a"); Special.create!(name: "b"); Item.where(name: "a").to_a; Special.find_by(name: "b")
    Item.all.map(&:name); Part.create!(item_id: 1).reload; Other.count
    out["stable"] = epochs.() == before

    change = lambda do |&blk|
      a = epochs.()
      blk.call
      b = epochs.()
      b.keys.select { a[_1] != b[_1] }
    end
    out["reset_column_information"] = change.() { Special.reset_column_information }
    out["default_scope"] = change.() { Part.class_eval { default_scope { where(item_id: 1) } } }
    out["after_initialize"] = change.() { Item.after_initialize { } }
    out["skip_callback"] = change.() { Item.reset_callbacks(:initialize) }
    out["has_many"] = change.() { Item.has_many :parts }
    out["attribute"] = change.() { Other.attribute :extra, :integer }
    Other.new # load the schema the earlier `attribute` call reset
    out["define_attribute"] = change.() { Other.define_attribute("name", ActiveRecord::Type::Integer.new) }
    out["reset_primary_key"] = change.() { Part.reset_primary_key }
    out["enum"] = change.() { Item.enum :state, { on: 0, off: 1 } }
    out["serialize"] = change.() { Other.serialize :name, coder: JSON }
    out["establish_connection"] = change.() { Other.establish_connection(adapter: "sqlite3", database: ":memory:") }
    out["private_kept"] = [:load_schema!, :default_scope, :reload_schema_from_cache].none? { Item.respond_to?(_1) }
    out["public_kept"] = Item.respond_to?(:attribute) && Item.respond_to?(:establish_connection)
    puts JSON.generate(out)
  RUBY

  def test_epochs
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "scenario.rb"), SCENARIO)
      out, err, status = ruby("-I#{GEM_LIB}", "scenario.rb", chdir: dir, setup: false)
      skip "install activerecord 8.1.4 and sqlite3 to run AR guard tests" if err.include?("Could not find 'activerecord'")
      assert status.success?, err
      r = JSON.parse(out.lines.last)
      assert r["hooked"], "installed through on_load"
      assert r["stable"], "ordinary reads/writes must not move epochs"
      assert_equal ["Special"], r["reset_column_information"], "descendants only, not the parent"
      assert_equal ["Part"], r["default_scope"]
      assert_equal %w[Item Special], r["after_initialize"], "inherited by STI subclasses"
      assert_equal %w[Item Special], r["skip_callback"]
      assert_equal %w[Item Special], r["has_many"]
      assert_equal ["Other"], r["attribute"]
      assert_equal ["Other"], r["define_attribute"], "types change without a schema reload"
      assert_equal ["Part"], r["reset_primary_key"]
      assert_equal %w[Item Special], r["enum"]
      assert_equal ["Other"], r["serialize"]
      assert_equal %w[Item Special Part Other], r["establish_connection"], "connection changes are global"
      assert r["private_kept"], "hooks must keep private class methods private"
      assert r["public_kept"]
    end
  end
end
