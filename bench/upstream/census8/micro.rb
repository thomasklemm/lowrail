# frozen_string_literal: true

# Census 8 per-call micro, for a Rails checkout given in RAILS:
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N ir     N calls inside Array#cycle (GC off), for
#                                                         Callgrind --toggle-collect=rb_ary_cycle (ir.sh)
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N stats  objects per call
# Loads Rails from the checkout's lib directories, so a Ruby without a bundle (master) runs it too.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord actionview].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext/string/inflections"
require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.references :author; t.string :title; t.timestamps }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author; end
AUTHOR = Author.create!(name: "a")
3.times { AUTHOR.posts.create!(title: "t") }

[ActiveSupport::Inflector.method(:pluralize), ActionView::Helpers::AssetUrlHelper.instance_method(:asset_path),
  ActiveRecord::Base.method(:find)].each do |m|
  raise "#{m.name} not loaded from #{rails}" unless m.source_location.first.start_with?(File.expand_path(rails) + "/")
end
VIEW = ActionView::Base.empty
WHERE = Post.where(author_id: 1)
ALL = Post.all

CASES = {
  "asset_path" => -> { VIEW.asset_path("application.css") },
  "asset_path_js" => -> { VIEW.asset_path("controllers/hello_controller", type: :javascript) },
  "asset_path_url" => -> { VIEW.asset_path("https://cdn.example.com/x.js") },
  "stylesheet_link_tag" => -> { VIEW.stylesheet_link_tag("application") },
  "ies_get" => -> { ActiveSupport::IsolatedExecutionState[:active_record_connected_to_stack] },
  "where_clause" => -> { WHERE.where_clause },
  "having_clause" => -> { ALL.having_clause },
  "current_shard" => -> { ActiveRecord::Base.current_shard },
  "pluralize" => -> { "comment".pluralize },
  "singularize" => -> { "contacts".singularize },
  "find" => -> { Post.find(1) },
  "where_to_a" => -> { Post.where(author_id: 1).to_a },
  "assoc_to_a" => -> { AUTHOR.posts.reset; AUTHOR.posts.to_a },
}

name, n, mode = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
fn = CASES.fetch(name)
500.times { fn.() }
GC.start
GC.disable
case mode
when "ir"
  [nil].cycle(n) { fn.() }
when "stats"
  before = GC.stat(:total_allocated_objects)
  1000.times { fn.() }
  puts "#{name} #{RUBY_DESCRIPTION[/\A\S+ \S+/]} #{(GC.stat(:total_allocated_objects) - before) / 1000.0} objects"
end
