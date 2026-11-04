require_relative "/home/user/w/scratch/setup"
ActiveRecord::Schema.define { create_table(:comments) { |t| t.integer :post_id; t.string :body } }
class Comment < ActiveRecord::Base; belongs_to :post; end
class Post; has_many :comments; end
class Author; has_many :comments, through: :posts; end
r = Author.reflect_on_association(:comments)
p r.class, r.method(:options).source_location
puts r.method(:options).source rescue puts "(no source)"
calls = Hash.new(0)
tp = TracePoint.new(:call) { |t| calls[caller_locations(2,1)[0].then { "#{_1.path.sub(/.*active_record\//,'')}:#{_1.lineno} #{_1.label}" }] += 1 if t.method_id == :options && t.self.is_a?(ActiveRecord::Reflection::ThroughReflection) }
a = AUTHOR; 3.times { |i| Post.create!(title: "x", author: a).comments.create!(body: "c") }
tp.enable { a.comments.reset; a.comments.to_a; Author.preload(:comments).to_a; Author.includes(:comments).references(:comments).to_a; a.comments.where(body: "c").count }
calls.sort_by { -_2 }.first(15).each { puts "#{_2}\t#{_1}" }
