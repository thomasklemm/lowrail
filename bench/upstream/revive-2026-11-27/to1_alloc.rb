require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.boolean :published }
end

class Post < ActiveRecord::Base; end
Post.create!(title: "Hello", published: true)

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.first, view, {})

{
  "text_field_tag" => -> { view.text_field_tag(:query, "rails") },
  "hidden_field_tag" => -> { view.hidden_field_tag(:token, "abc") },
  "submit_tag" => -> { view.submit_tag("Save") },
  "tag.input" => -> { view.tag.input(type: "text", name: "q") },
  "f.text_field" => -> { form.text_field(:title) },
  "f.check_box" => -> { form.check_box(:published) },
}.each do |name, field|
  field.call
  before = GC.stat(:total_allocated_objects)
  1000.times { field.call }
  puts "#{name}: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
end
