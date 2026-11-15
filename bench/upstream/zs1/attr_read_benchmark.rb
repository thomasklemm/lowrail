# frozen_string_literal: true

# ruby-bench benchmark for ZS1 (docs/upstream/zjit-symbol-block.md): the first attribute reads of rails/rails#59803,
# 10 records with 30 columns, every attribute read once. Copy to <ruby-bench>/benchmarks/attr-read/benchmark.rb;
# it uses railsbench's Gemfile, so Active Record comes from the tree that Gemfile points at.
require_relative "../../lib/harness/loader"

Dir.chdir File.expand_path("../railsbench", __dir__)
use_gemfile
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", reaping_frequency: 0)
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
COLS = (1..28).map { |i| ["c#{i}", i.odd? ? :string : :integer] }
ActiveRecord::Schema.define do
  create_table(:items) do |t|
    t.string :type
    COLS.each { |name, type| t.column name, type }
  end
end
class Item < ActiveRecord::Base
  class_eval "def self.read_all(r) = (r.id; r.type; #{COLS.map { |n, _| "r.#{n}" }.join("; ")})"
end

10.times { Item.create!(COLS.to_h { |name, type| [name, type == :string ? "value #{name}" : name.delete("c").to_i] }) }
ROWS = Item.connection.select_all(Item.where(id: 1..10).arel)

run_benchmark(20) do
  5_000.times { Item._load_from_sql(ROWS).each { |r| Item.read_all(r) } }
end
