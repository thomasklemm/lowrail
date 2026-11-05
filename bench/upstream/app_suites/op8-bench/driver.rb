# OP8 instruction micro. ruby driver.rb WORKLOAD N  (RAILS_PATH set; Gemfile next to this file)
# WORKLOAD: newplain = Model.new + first read of every attribute: integer, boolean and string defaults, plus
#                      ruby-bench's Post (no column defaults);
#           newcont  = the same for a model with a JSON-serialized text default and a json default;
#           newnested = the same for a model with a nested JSON-serialized default (the case the fix changes);
#           newnull = the same for a model with a NULL-default json column next to integer and string defaults;
#           rbar = ruby-bench activerecord's run (100 posts with their comments, attribute reads).
require "bundler/setup"
require "active_record"
require "json"
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.string :title, null: false; t.string :body; t.string :type_name, null: false; t.string :key, null: false
    t.integer :upvotes, null: false; t.integer :author_id, null: false; t.timestamps
  end
  create_table :comments, force: true do |t|
    t.integer :post_id; t.integer :author_id; t.text :body; t.string :tags; t.datetime :published_at; t.timestamps
  end
  create_table :settings, force: true do |t|
    t.integer :count, default: 0; t.boolean :enabled, default: false; t.string :name, default: "untitled"
  end
  create_table :nesteds, force: true do |t|
    t.text :cfg, default: '{"a":{"b":1}}'
  end
  create_table :profiles, force: true do |t|
    t.json :data; t.string :name, default: "x"; t.integer :n, default: 0
  end
  create_table :documents, force: true do |t|
    t.text :prefs, default: "{}"; t.json :meta, default: {}
  end
end
class Post < ActiveRecord::Base; has_many :comments, inverse_of: :post; end
class Comment < ActiveRecord::Base; belongs_to :post, inverse_of: :comments; end
class Setting < ActiveRecord::Base; end
class Document < ActiveRecord::Base; serialize :prefs, coder: JSON; end
class Nested < ActiveRecord::Base; serialize :cfg, coder: JSON; end
class Profile < ActiveRecord::Base; end
srand(1)
Post.transaction do
  100.times do |i|
    post = Post.create!(title: "t" * 30, type_name: "x" * 10, key: "k#{i}", body: "b" * 100, upvotes: i % 30, author_id: i % 30)
    20.times { |j| post.comments.create!(author_id: j, body: "c" * 30, tags: "g" * 30, published_at: Time.at(0)) }
  end
end
work = case ARGV[0]
when "newplain"
  -> {
    s = Setting.new; s.count; s.enabled; s.name
    p = Post.new; p.title; p.body; p.upvotes; p.created_at
  }
when "newcont"
  -> { d = Document.new; d.prefs; d.meta }
when "newnull"
  -> { p = Profile.new; p.data; p.name; p.n }
when "newnested"
  -> { n = Nested.new; n.cfg }
when "rbar"
  -> {
    Post.includes(:comments).order(id: :asc).limit(100).each do |post|
      post.title; post.title; post.title; post.body; post.type_name; post.upvotes; post.updated_at
      post.comments.each { |c| c.body; c.published_at }
    end
  }
end
3.times { work.call }
GC.start
GC.disable
Array.new(Integer(ARGV[1])) { work.call }
