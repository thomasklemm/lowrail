# frozen_string_literal: true

# Census 10: per-call Ir and objects of association loads after the owner-condition
# changes on main (2026-11-16/17), for a Rails checkout in RAILS (lib directories,
# no bundle). Same measurement as census 9's req_micro.rb (IrCount under census 8's
# patched Callgrind, --instr-atstart=no; N calls after WARM warmup calls, fixed heap
# from the caller; YJIT warms until three windows compile nothing).
# Prints CASE Ir/call objects/call jit (jit = YJIT blocks compiled in the window).
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/c10/ext/ir_count.so"))

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveSupport.event_reporter.debug_mode = false if ActiveSupport.respond_to?(:event_reporter)
ActiveRecord::Migration.verbose = false
# The 8.2 default for new apps; 8.1 has no such setting.
if ENV["KEEP"] && ActiveRecord.respond_to?(:association_scope_keeps_owner_conditions=)
  ActiveRecord.association_scope_keeps_owner_conditions = ENV["KEEP"] == "1"
end
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) { |t| t.references :author; t.string :title; t.boolean :published, default: true; t.timestamps }
  create_table(:comments) { |t| t.references :post; t.string :body; t.boolean :visible, default: true; t.timestamps }
  create_table(:profiles) { |t| t.references :author; t.string :bio }
  create_table(:pictures) { |t| t.references :imageable, polymorphic: true; t.string :url }
end
class Author < ActiveRecord::Base
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
  has_many :comments, through: :posts
  has_one :profile
  has_many :pictures, as: :imageable
end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  has_many :visible_comments, -> { where(visible: true).order(:id) }, class_name: "Comment"
end
class Comment < ActiveRecord::Base; belongs_to :post; end
class Profile < ActiveRecord::Base; belongs_to :author; end
class Picture < ActiveRecord::Base; belongs_to :imageable, polymorphic: true; end
AUTHOR = Author.create!(name: "a")
3.times { |i| AUTHOR.posts.create!(title: "t#{i}") }
POST = Post.first
3.times { POST.comments.create!(body: "c") }
AUTHOR.create_profile!(bio: "b")
2.times { AUTHOR.pictures.create!(url: "u") }
COMMENT = Comment.first
AUTHORS = Author.where(id: AUTHOR.id)

CASES = {
  "has_many" => -> { AUTHOR.posts.reset; AUTHOR.posts.to_a },
  "has_many_scoped" => -> { AUTHOR.published_posts.reset; AUTHOR.published_posts.to_a },
  "has_many_where" => -> { AUTHOR.posts.where(title: "t1").to_a },
  "has_many_through" => -> { AUTHOR.comments.reset; AUTHOR.comments.to_a },
  "has_many_as" => -> { AUTHOR.pictures.reset; AUTHOR.pictures.to_a },
  "has_one" => -> { AUTHOR.association(:profile).reset; AUTHOR.profile },
  "belongs_to" => -> { COMMENT.association(:post).reset; COMMENT.post },
  "preload_has_many" => -> { AUTHORS.preload(:posts).to_a },
  "preload_through" => -> { AUTHORS.preload(:comments).to_a },
  "joins_has_many" => -> { Author.joins(:posts).to_sql },
  "joins_through" => -> { Author.joins(:comments).to_sql },
  "count_has_many" => -> { AUTHOR.posts.count },
}.freeze

n = Integer(ENV.fetch("N", "100"))
warm = Integer(ENV.fetch("WARM", "100"))
yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
blocks = -> { yjit ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
IrCount.start if IrCount.running?
(ARGV.empty? ? CASES.keys : ARGV).each do |name|
  fn = CASES.fetch(name)
  warm.times { fn.() }
  if yjit
    flat = 0
    30.times do
      b = blocks.()
      n.times { fn.() }
      flat = blocks.() == b ? flat + 1 : 0
      break if flat == 3
    end
  end
  GC.start
  GC.disable
  b0 = blocks.()
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  n.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  jit = blocks.() - b0
  GC.enable
  puts format("%-20s %12.1f %8.2f %d", name, (i1 - i0).fdiv(n), (o1 - o0).fdiv(n), jit)
  $stdout.flush
end
