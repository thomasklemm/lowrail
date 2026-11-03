require "bundler/setup"
require "action_view"
view = ActionView::Base.empty
Post = Struct.new(:status)
post = Post.new("In progress")
tag = ActionView::Helpers::Tags::Base.allocate
v = "In progress"
c = { "radio_button" => -> { view.radio_button(:post, :status, "In progress", object: post) },
      "sanitized_value" => -> { tag.send(:sanitized_value, v) } }
c.each do |k, f|
  3.times { 2000.times { f.() } }
  GC.disable; b = GC.stat(:total_allocated_objects); 2000.times { f.() }; a = GC.stat(:total_allocated_objects); GC.enable
  puts "#{ENV["LABEL"]}\t#{k}\t#{(a - b) / 2000.0}"
end
