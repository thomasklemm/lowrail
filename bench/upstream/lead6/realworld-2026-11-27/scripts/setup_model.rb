# frozen_string_literal: true

# Shared setup: a posts table with COLS columns (id, created_at, updated_at plus
# string/integer/boolean groups) on SQLite in memory, or PostgreSQL with DB=pg.
require "active_record"

COLS = Integer(ENV.fetch("COLS", "30"))
groups = (COLS - 3) / 3
extra = (COLS - 3) % 3

if ENV["DB"] == "pg"
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "l6rw", host: "/var/run/postgresql")
else
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
end
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    groups.times { |i| t.string "title_#{i}"; t.integer "count_#{i}"; t.boolean "flag_#{i}" }
    extra.times { |i| t.string "extra_#{i}" }
    t.timestamps
  end
end

class Post < ActiveRecord::Base; end

VALUES = {}
groups.times { |i| VALUES.merge!("title_#{i}" => "Hello", "count_#{i}" => i, "flag_#{i}" => true) }
extra.times { |i| VALUES["extra_#{i}"] = "x" }
POST_ID = Post.create!(VALUES).id
raise "columns #{Post.columns.size} != #{COLS}" unless Post.columns.size == COLS

def l6_cases
  post = Post.find(POST_ID)
  hash_post = Post.find(POST_ID)
  {
    "update" => -> { post.update!(count_0: post.count_0 + 1) },
    "find_update" => -> { p = Post.find(POST_ID); p.update!(count_0: p.count_0 + 1) },
    "find_changed" => -> { Post.find(POST_ID).changed? },
    "serializable_hash" => -> { hash_post.serializable_hash }
  }
end

# Real-world shapes: a fresh record per operation, as in a request.
def fresh_cases
  {
    "find_update" => -> { p = Post.find(POST_ID); p.update!(count_0: p.count_0 + 1) },
    "find_read_update" => -> { p = Post.find(POST_ID); p.title_0; p.count_1; p.update!(count_0: p.count_0 + 1) },
    "find_changed" => -> { Post.find(POST_ID).changed? }
  }
end
