require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.string :category }
end

class Post < ActiveRecord::Base; end
Post.create!(title: "Hello", body: "Text", category: "news")

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.first, view, {})

{
  "text_field" => -> { form.text_field(:title) },
  "text_area" => -> { form.text_area(:body) },
  "radio_button" => -> { form.radio_button(:category, "news") },
  "label" => -> { form.label(:title) },
}.each do |name, field|
  field.call
  before = GC.stat(:total_allocated_objects)
  1000.times { field.call }
  puts "#{name}: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
end
