require "bundler/setup"
require "active_record"
puts "AR #{ActiveRecord::VERSION::STRING} from #{Gem.loaded_specs['activerecord']&.full_gem_path || $LOADED_FEATURES.grep(/active_record\.rb/).first}"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
end
class Comment < ActiveRecord::Base
  belongs_to :post
  SAVED = []
  after_save { SAVED << id }
end
class Post < ActiveRecord::Base
  has_many :comments, autosave: true
end
set_ctx = ->(r, c) { r.respond_to?(:validation_context=, true) ? r.send(:validation_context=, c) : r.send(:context_for_validation).context = c }

p1 = Post.create!(title: "a"); 2.times { |i| p1.comments.create!(body: "c#{i}") }

# 1. strict_loading
[nil, :import].each do |ctx|
  post = Post.find(p1.id); post.strict_loading!
  set_ctx.(post, ctx)
  r = begin; post.comments.to_a.size; rescue => e; e.class.name; end
  puts "strict_loading, preset context=#{ctx.inspect}: #{r}"
end

# 2. autosave save phase: unchanged loaded children
[nil, :import].each do |ctx|
  post = Post.find(p1.id); post.comments.load
  Comment::SAVED.clear
  set_ctx.(post, ctx)
  post.title = "b#{ctx}"; post.save!
  puts "autosave, preset context=#{ctx.inspect}: unchanged children saved=#{Comment::SAVED.inspect}, context after save=#{post.validation_context.inspect}, custom_validation_context?=#{post.custom_validation_context?.inspect}"
end
