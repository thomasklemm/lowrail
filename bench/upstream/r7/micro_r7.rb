# Per-call objects for the R7 candidates. Run from a Rails worktree with `bundle exec`.
require "action_view"
require "active_record"
require "active_support/core_ext/object/json"
require "active_support/number_helper"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.references :author; t.string :title }
  create_table(:comments) { |t| t.references :post; t.string :body }
end
class Author < ActiveRecord::Base; end
class Post < ActiveRecord::Base; belongs_to :author; end
class Comment < ActiveRecord::Base
  belongs_to :post
  has_one :post_author, through: :post, source: :author
end
comment = Comment.create!(post: Post.create!(author: Author.create!(name: "a"), title: "t"), body: "b")
comment = Comment.find(comment.id)
comment.post_author

include ActionView::Helpers::TagHelper
attrs = { id: 1, name: "David", email: "d@example.com", created_at: nil }
nested = ["btn", ["btn-primary", { "active" => true }]]
classes = ["btn", "btn-primary"]

N = 2_000
def per_call(&blk)
  500.times { blk.() }
  GC.start; GC.disable
  o0 = GC.stat(:total_allocated_objects)
  N.times { blk.() }
  o = GC.stat(:total_allocated_objects) - o0
  GC.enable
  o.fdiv(N).round(2)
end

CASES = {
  "C1 class_names(\"btn\", active: true)" => -> { class_names("btn", active: true) },
  "C1 class_names(nested Array)" => -> { class_names(*nested) },
  "C1 tag.div(class: [\"btn\", \"btn-primary\"])" => -> { tag.div(class: classes) },
  "C1 tag.div(class: { active: true })" => -> { tag.div(class: { active: true }) },
  "C1 tag.div(aria: { describedby: [..] })" => -> { tag.div(aria: { describedby: classes }) },
  "C2 {4 Symbol keys}.as_json" => -> { attrs.as_json },
  "C2 {4 Symbol keys}.as_json(except: :created_at)" => -> { attrs.as_json(except: :created_at) },
  "C2 render json: { post: {4 keys} } (as_json({}))" => -> { { post: attrs }.as_json({}) },
  "C3 comment.post_author (loaded through belongs_to)" => -> { comment.post_author },
  "C4 number_to_currency(1234.5)" => -> { ActiveSupport::NumberHelper.number_to_currency(1234.5) },
  "C4 number_to_currency(-5, unit: \"€\")" => -> { ActiveSupport::NumberHelper.number_to_currency(-5, unit: "€") },
}

mode = if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? then "zjit"
elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? then "yjit"
else "interp" end
CASES.each { |name, f| puts [RUBY_VERSION, mode, ENV.fetch("LABEL"), name, per_call(&f)].join("\t") }
