require "active_support/all"
require "active_model"
require "action_view"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  validates :title, presence: true
end

post = Post.new(title: "Hello")
post.valid?
view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, post, view, {})

{ "errors[:title]" => -> { post.errors[:title] },
  "text_field" => -> { form.text_field(:title) } }.each do |name, call|
  call.call
  before = GC.stat(:total_allocated_objects)
  1000.times { call.call }
  puts "#{name}: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
end
