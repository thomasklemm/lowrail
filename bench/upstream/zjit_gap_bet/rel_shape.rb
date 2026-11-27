# Screening micro (BUNDLE_GEMFILE=micro.Gemfile): does defining Relation#reset's ivars in Relation#initialize (one shape) save work?
#   ruby rel_shape.rb base|patch N [case]
require "bundler/setup"
require "active_record"

VARIANT, N, CASE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "chain"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.string :body; t.integer :author_id }
end
class Post < ActiveRecord::Base; end
3.times { |i| Post.create!(title: "t#{i}", body: "b", author_id: i) }

if VARIANT == "patch"
  ActiveRecord::Relation.class_eval do
    def initialize(model, table: nil, predicate_builder: nil, values: {})
      if table
        predicate_builder ||= model.predicate_builder.with(ActiveRecord::TableMetadata.new(model, table))
      else
        table = model.arel_table
        predicate_builder ||= model.predicate_builder
      end

      @model  = model
      @table  = table
      @values = values
      @loaded = false
      @predicate_builder = predicate_builder
      @delegate_to_model = false
      @future_result = nil
      @records = nil
      @async = false
      @none = false
      @to_sql = @arel = @should_eager_load = nil
      @offsets = @take = nil
      @cache_keys = @cache_versions = nil
    end
  end
end

CASES = {
  "chain" => -> { Post.where(title: "t1").where(author_id: 1).order(:id).limit(2) },
  "chain_sql" => -> { Post.where(title: "t1").order(:id).limit(2).to_sql },
  "load" => -> { Post.where(title: "t1").order(:id).limit(2).to_a },
  "find_by" => -> { Post.find_by(title: "t1") },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start
GC.disable
if ENV["CG"]
  [0].cycle(1) { N.times { f.() } }
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts ((Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t) / N.to_f).round(1)
end
