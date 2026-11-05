# frozen_string_literal: true

$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map {
  File.join(ENV.fetch("RAILS_PATH"), _1, "lib")
})
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) }
class Post < ActiveRecord::Base; end

right = Post.readonly(true)
value = Object.new
value.define_singleton_method(:==) { |_| right.offset!(2); true }
left = Post.readonly(value)
begin
  puts "compatible: #{left.structurally_compatible?(right)}"
rescue => error
  puts "#{error.class}: #{error.message}"
end
puts "other offset: #{right.offset_value}"

right = Post.readonly(true).offset(1)
value = Object.new
value.define_singleton_method(:==) { |_| right.offset!(2); true }
left = Post.readonly(value).offset(1)
Post.define_singleton_method(:unscoped) { right }
puts "empty scope: #{left.empty_scope?}"
