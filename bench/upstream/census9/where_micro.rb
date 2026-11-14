# frozen_string_literal: true

# Census 9: per-call Ir of String-condition where clauses, for #59642 (CW1),
# for a Rails checkout in RAILS. Same measurement as attr_micro.rb (IrCount
# under census 8's patched Callgrind, --instr-atstart=no; N calls after WARM).
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_record"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/c9/ext/ir_count.so"))

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :views; t.timestamps } }
class Post < ActiveRecord::Base; end
3.times { Post.create!(title: "t#{_1}", views: _1) }

CASES = {
  "where_str_bind" => -> { Post.where("title = ?", "t1") },
  "where_str_bind_to_sql" => -> { Post.where("title = ?", "t1").to_sql },
  "where_two_str_to_sql" => -> { Post.where("title = ?", "t1").where("views > ?", 0).to_sql },
  "where_hash_and_str_to_a" => -> { Post.where(views: 1).where("title = ?", "t1").to_a },
  "where_named_to_sql" => -> { Post.where("title = :t", t: "t1").to_sql },
}.freeze

n = Integer(ENV.fetch("N", "500"))
warm = Integer(ENV.fetch("WARM", "300"))
IrCount.start if IrCount.running?
(ARGV.empty? ? CASES.keys : ARGV).each do |name|
  fn = CASES.fetch(name)
  warm.times { fn.() }
  GC.start
  GC.disable
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  n.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  GC.enable
  puts format("%-28s %12.1f %8.2f %s", name, (i1 - i0).fdiv(n), (o1 - o0).fdiv(n), fn.().then { _1.is_a?(String) ? _1[/WHERE.*/] : "" })
end
