# fb1_ir.sh runs this under Callgrind: the body's ActiveModel Post (PERSISTED=1 makes persisted? true), 3,000 warm-up calls, GC off, N calls inside Array#cycle.
field, persisted, n = ARGV
require "active_support/all"
require "active_model"
require "action_view"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :published, :boolean
end
Post.define_method(:persisted?) { true } if persisted == "1"

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello", published: true), view, {})
op = field == "checkbox" ? -> { form.checkbox(:published) } : -> { form.text_field(:title) }
3000.times { op.call }
GC.start
GC.disable unless ENV["GCON"]
[op].cycle(Integer(n)) { |o| o.call }
