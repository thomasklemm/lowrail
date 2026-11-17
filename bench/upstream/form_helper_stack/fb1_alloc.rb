require "active_support/all"
require "active_model"
require "action_view"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :published, :boolean
end

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello", published: true), view, {})

{ "text_field" => -> { form.text_field(:title) }, "checkbox" => -> { form.checkbox(:published) } }.each do |name, field|
  field.call
  before = GC.stat(:total_allocated_objects)
  1000.times { field.call }
  puts "#{name}: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
end
