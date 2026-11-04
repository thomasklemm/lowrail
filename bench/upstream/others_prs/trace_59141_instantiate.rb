require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :score; t.timestamps } }
class Post < ActiveRecord::Base; end
Post.create!(title: "a", score: 1)
A = Post.first.attributes_before_type_cast.freeze
3.times { Post.instantiate(A) }
calls = Hash.new(0)
tp = TracePoint.new(:call, :c_call) { |t| calls["#{t.defined_class}##{t.method_id}"] += 1 }
tp.enable { Post.instantiate(A) }
calls.sort_by { -_2 }.first(40).each { puts "#{_2} #{_1}" }
