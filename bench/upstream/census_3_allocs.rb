# frozen_string_literal: true

# Allocation micro for the census-3 candidates: ruby [--yjit] census_3_allocs.rb RAILS_ROOT
# Objects per warmed operation, GC disabled during the 2,000-operation window.
root = ARGV.fetch(0)
%w[activesupport activemodel activerecord].each { $LOAD_PATH.unshift File.join(root, _1, "lib") }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :author_id } }
class Post < ActiveRecord::Base; end
Post.create!(title: "a", author_id: 1)
t = Post.arel_table
conn = Post.lease_connection
def per_op(n = 2_000)
  200.times { yield }
  GC.start; GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { yield }
  (GC.stat(:total_allocated_objects) - before).fdiv(n)
ensure
  GC.enable
end
one = Post.where(id: 1)
two = Post.where(id: 1).where(title: "a")
sql = Post.where("author_id > 0")
cases = {
  "WhereClause#ast, one predicate" => -> { one.where_clause.ast },
  "WhereClause#ast, two predicates" => -> { two.where_clause.ast },
  "WhereClause#ast, SQL string predicate" => -> { sql.where_clause.ast },
  "SelectManager#project(one) + #order(one)" => -> { Arel::SelectManager.new(t).project(t[Arel.star]).order(t[:id]) },
  "Relation#arel, where(id:)" => -> { Post.where(id: 1).arel },
  "select_all, one row" => -> { conn.select_all("SELECT id FROM posts") },
  "Post.find (statement cache)" => -> { Post.find(1) },
}
printf "%s %s\n", RUBY_DESCRIPTION, (defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?) ? "YJIT" : "interpreter"
cases.each { |name, op| printf "%-42s %.3f\n", name, per_op(&op) }
