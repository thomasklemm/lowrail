# frozen_string_literal: true

# Behavior snapshots for the census-3 candidates; run against clean and changed
# Rails checkouts and diff the output. ruby census_3_controls.rb RAILS_ROOT
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
out = []
snap = ->(label, value) { out << "#{label}: #{value.inspect}" }

# WhereClause#ast: empty-string removal, SQL literal wrapping, order, sharing.
wc = ActiveRecord::Relation::WhereClause
lit = Arel.sql("x = 1")
plain = +"y = 2"
sub = Class.new(String).new("")
[[[]], [[""]], [["", ""]], [[lit]], [[plain]], [["", lit, "", t[:id].eq(1)]],
 [[t[:id].eq(1), Arel.sql(""), t[:title].eq("a")]], [[sub, t[:id].eq(1)]]].each_with_index do |(preds), i|
  ast = wc.new(preds).ast
  snap.("ast#{i}", [ast.class, ast.respond_to?(:children) ? ast.children.map(&:class) : nil])
end
preds = [lit, t[:id].eq(1)].freeze
w = wc.new(preds)
a1 = w.ast; a2 = w.ast
snap.("ast fresh", [a1.equal?(a2), a1.children.equal?(a2.children), w.send(:predicates).equal?(preds)])
snap.("sql", Post.where("author_id > 0").where(id: 1).where("").to_sql)
snap.("or sql", Post.where(id: 1).or(Post.where("title = 'a'")).to_sql)

# Arel project/order/window: caller arrays and their elements are not mutated.
args = ["id", :title, t[:author_id]]
m = Arel::SelectManager.new(t)
m.project(*args).order(*args)
snap.("project callers", [args[0, 2], args[2].name, args.map(&:class), args.frozen?])
snap.("project sql", m.to_sql)
win = Arel::Nodes::Window.new
win.order(*args).partition(*args)
snap.("window", [args.map(&:class), win.orders.map(&:class), win.partitions.map(&:class)])
snap.("order sql", Post.order("title DESC", :id).select("id", :title).to_sql)
m2 = Arel::SelectManager.new(t)
m2.project
snap.("empty project", m2.projections)

# Warnings: empty results are frozen-shared only on the path that has none.
conn = Post.lease_connection
w1 = conn.send(:collect_warnings, nil)
w2 = conn.send(:collect_warnings, nil)
snap.("warnings", [w1, w1.frozen?, w1.equal?(w2)])
handled = []
ActiveRecord.db_warnings_action = ->(warning) { handled << warning.message }
conn.select_all("SELECT 1")
snap.("handled", handled)
puts out
