# frozen_string_literal: true

# Allocation micro for the census-3b candidates: ruby [--yjit] census_3b_allocs.rb RAILS_ROOT
# Objects per warmed operation, GC disabled during the 2,000-operation window.
root = ARGV.fetch(0)
%w[activesupport activemodel activerecord actionview].each { $LOAD_PATH.unshift File.join(root, _1, "lib") }
require "active_record"
require "action_view"
require "active_support/hash_with_indifferent_access"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors)
  create_table(:posts) { |t| t.integer :author_id; t.integer :status }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author; enum :status, { draft: 0, live: 1 }; end
a = Author.create!
Post.create!(author: a, status: :live)
v = ActionView::Base.empty
h = ActiveSupport::HashWithIndifferentAccess.new(a: 1)
def per_op(n = 2_000)
  200.times { yield }
  GC.start; GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { yield }
  (GC.stat(:total_allocated_objects) - before).fdiv(n)
ensure
  GC.enable
end
cases = {
  "tag.span(\"x\", class: \"a\")" => -> { v.tag.span("x", class: "a") },
  "tag.my_widget(\"x\")" => -> { v.tag.my_widget("x") },
  "HWIA#fetch(:a)" => -> { h.fetch(:a) },
  "HWIA#fetch(:z, 0)" => -> { h.fetch(:z, 0) },
  "enum serialize(\"live\")" => -> { Post.type_for_attribute(:status).serialize("live") },
  "Post.where(author_id:).load" => -> { Post.where(author_id: a.id).load },
  "Post.joins(:author).load" => -> { Post.joins(:author).load },
}
printf "%s %s\n", RUBY_DESCRIPTION, (defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?) ? "YJIT" : "interpreter"
cases.each { |name, op| printf "%-32s %.3f\n", name, per_op(&op) }
