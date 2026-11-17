require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title }
end

class Post < ActiveRecord::Base; end

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello"), view, {})

form.label(:title)
before = GC.stat(:total_allocated_objects)
1000.times { form.label(:title) }
puts "label: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
