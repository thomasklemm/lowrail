# frozen_string_literal: true

# Behavior controls for others' open Active Record PRs (docs/upstream/others-prs-census.md):
# #59141 (row-indexed attributes), #58002 (LazyAttributeSet#keys), #59530 (SchemaContext split).
# Prints one line per case: its result or the exception it raised. Run the same script in a bundle of
# each tree and diff the outputs. ADAPTER=sqlite3 (default) or postgresql (DATABASE=name).
#   ruby controls.rb > out.txt
require "active_record"
require "yaml"

adapter = ENV.fetch("ADAPTER", "sqlite3")
if adapter == "postgresql"
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: ENV.fetch("DATABASE", "oc_controls"))
else
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
end
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.time_zone_aware_attributes = true
Time.zone = "UTC"

ActiveRecord::Schema.define do
  create_table(:authors, force: true) { |t| t.string :name; t.integer :rank, default: 3; t.timestamps }
  create_table(:posts, force: true) do |t|
    t.references :author
    t.string :title
    t.text :body
    t.string :type
    t.string :kind
    t.integer :status, default: 0
    t.integer :score
    t.text :meta
    t.boolean :published, default: false
    t.timestamps
  end
  create_table(:comments, force: true) { |t| t.references :post; t.string :body; t.string :type }
  create_table(:pairs, primary_key: [:a, :b], force: true) { |t| t.integer :a; t.integer :b; t.string :v }
  create_table(:nopks, id: false, force: true) { |t| t.string :v }
  create_table(:legacy_rows, primary_key: :code, id: :string, force: true) { |t| t.string :v }
  create_table(:widgets, force: true) { |t| t.string :name; t.string :colour }
end

class Author < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :author, optional: true
  has_many :comments
  enum :status, [:draft, :live]
  serialize :meta, coder: JSON
  attribute :virtual_n, :integer, default: 7
  attribute :score, :string
end
class Article < Post
  attribute :extra, :string, default: "x"
end
class Note < Post; end
class Comment < ActiveRecord::Base
  belongs_to :post
end
class Reply < Comment; end
class Pair < ActiveRecord::Base; end
class Nopk < ActiveRecord::Base; end
class LegacyRow < ActiveRecord::Base; end

def show(value)
  case value
  when ActiveRecord::Base
    "#{value.class.name}(#{value.attributes.map { |k, v| "#{k}=#{show(v)}" }.join(", ")})"
  when Array then "[" + value.map { show(_1) }.join(", ") + "]"
  when Hash then "{" + value.map { |k, v| "#{show(k)}=>#{show(v)}" }.join(", ") + "}"
  when Time, ActiveSupport::TimeWithZone then value.utc.iso8601(6)
  else value.inspect
  end
end

def check(name)
  result = yield
  puts "#{name}: #{show(result)}"
rescue Exception => e # rubocop:disable Lint/RescueException
  puts "#{name}: raised #{e.class}: #{e.message.lines.first.to_s.strip.gsub(/0x\h+/, "0x")}"
end

FIXED = Time.utc(2026, 1, 2, 3, 4, 5)
a1 = Author.create!(name: "Ann", created_at: FIXED, updated_at: FIXED)
a2 = Author.create!(name: "Bob", rank: 1, created_at: FIXED, updated_at: FIXED)
p1 = Post.create!(author: a1, title: "one", body: "b1", kind: "k", score: "10", created_at: FIXED, updated_at: FIXED)
p2 = Article.create!(author: a1, title: "two", body: "b2", status: :live, created_at: FIXED, updated_at: FIXED)
p3 = Note.create!(author: a2, title: "three", created_at: FIXED, updated_at: FIXED)
Comment.create!(post: p1, body: "c1")
Reply.create!(post: p2, body: "r1")
Pair.create!(a: 1, b: 2, v: "p")
Nopk.create!(v: "n")
LegacyRow.create!(code: "A1", v: "l")
Widget = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
Widget.create!(name: "w", colour: "red")

# Loading and reading attributes (#59141, #58002)
check("find") { Post.find(p1.id) }
check("where.to_a") { Post.order(:id).to_a }
check("sti classes") { Post.order(:id).map(&:class) }
check("sti subclass attrs") { Post.find(p2.id).attributes.keys }
check("subclass query") { Article.all.to_a }
check("keys order") { Post.first.attributes.keys }
check("attribute_names") { Post.select(:id, :title).first.attribute_names }
check("partial select read") { Post.select(:id).first.title }
check("partial select keys") { Post.select(:title, :id).first.attributes.keys }
check("partial select has_attribute?") { r = Post.select(:id).first; [r.has_attribute?(:title), r.has_attribute?(:id), r.attribute_present?(:id)] }
check("partial select sti") { Post.select(:id, :type).order(:id).map { [_1.class, _1.attributes] } }
check("partial select no type") { Post.select(:id).order(:id).map(&:class) }
check("alias column") { Post.select("title AS t, id").first.attributes }
check("alias shadows column") { Post.select("body AS title, id").order(:id).first.title }
check("extra computed") { r = Post.select("posts.*, 1 + 1 AS two").first; [r.two, r.attributes["two"], r.attributes.keys.last] }
check("duplicate column") { Post.select("posts.id, posts.title, posts.title").first.attributes }
check("join duplicate names") { Post.joins(:author).select("posts.*, authors.name, authors.id").order("posts.id").first.attributes }
check("join star") { Post.joins(:author).select("*").order("posts.id").first.attributes.slice("id", "name", "title") }
check("find_by_sql extra") { Post.find_by_sql("SELECT id, title, 'q' AS extra FROM posts ORDER BY id").map(&:attributes) }
check("find_by_sql sti") { Post.find_by_sql("SELECT * FROM posts ORDER BY id").map(&:class) }
check("find_by_sql unknown type") { Post.find_by_sql("SELECT id, 'Missing' AS type FROM posts").to_a }
check("find_by_sql empty type") { Post.find_by_sql("SELECT id, '' AS type FROM posts LIMIT 1").map(&:class) }
check("column type override") { r = Post.find(p1.id); [r.score, r.score.class, r.read_attribute_before_type_cast(:score)] }
check("select overrides typed column") { r = Post.select("id, 42 AS score").first; [r.score, r.score.class] }
check("virtual attribute") { r = Post.find(p1.id); [r.virtual_n, r.attributes["virtual_n"]] }
check("virtual attribute selected") { r = Post.select("id, 9 AS virtual_n").first; [r.virtual_n, r.virtual_n.class] }
check("enum") { Post.order(:id).pluck(:status) + Post.order(:id).map(&:status) }
check("serialize") { r = Post.find(p1.id); r.update_columns(meta: JSON.generate("x" => 1)); [Post.find(p1.id).meta, Post.find(p1.id).meta_before_type_cast] }
check("sti default extra") { r = Article.find(p2.id); [r.extra, r.attributes.keys] }
check("sti from base extra") { Post.find(p2.id).attributes }
check("pluck pick ids") { [Post.order(:id).pluck(:id, :title), Post.order(:id).pick(:title), Post.order(:id).ids] }
check("before_type_cast") { Post.find(p1.id).attributes_before_type_cast.slice("score", "status", "published") }
check("inspect") { Post.find(p1.id).inspect.gsub(/"\d{4}-\d\d-\d\d [^"]+"/, "T") }
check("as_json") { Post.find(p1.id).as_json.except("created_at", "updated_at") }
check("serializable_hash only") { Post.find(p1.id).serializable_hash(only: [:id, :title]) }
check("dirty after load") { r = Post.find(p1.id); [r.changed?, r.changes] }
check("dirty after write") { r = Post.find(p1.id); r.title = "x"; r.score = 5; [r.changed, r.changes] }
check("write unselected") { r = Post.select(:id).first; r.title = "x"; [r.title, r.changed] }
check("write unknown") { Post.find(p1.id).write_attribute(:nope, 1) }
check("assign attributes") { r = Post.find(p1.id); r.assign_attributes(title: "y", body: "z"); r.attributes.slice("title", "body") }
check("reload") { r = Post.find(p1.id); r.title = "x"; r.reload; [r.title, r.changed?] }
check("reload partial") { r = Post.select(:id).first; r.reload.attributes.keys }
check("dup") { d = Post.find(p1.id).dup; [d.id, d.new_record?, d.attributes.keys] }
check("clone") { c = Post.find(p1.id).clone; c.title = "c"; [c.title, c.id] }
check("becomes") { b = Post.find(p1.id).becomes(Article); [b.class, b.attributes, b.extra] }
check("becomes write") { r = Post.find(p1.id); b = r.becomes(Article); b.title = "bt"; [r.title, b.title, b.changed] }
check("becomes!") { b = Post.find(p3.id).becomes!(Article); [b.type, b.attributes.keys] }
check("marshal") { Marshal.load(Marshal.dump(Post.find(p1.id))).attributes }
check("marshal partial") { Marshal.load(Marshal.dump(Post.select(:id, :title).first)).attributes }
check("yaml") { YAML.unsafe_load(YAML.dump(Post.find(p1.id))).attributes }
check("yaml sti") { r = YAML.unsafe_load(YAML.dump(Post.find(p2.id))); [r.class, r.attributes.keys] }
check("instantiate hash") { Post.instantiate("id" => 99, "title" => "i", "unknown" => 1).attributes }
check("instantiate sti hash") { Post.instantiate("id" => 98, "type" => "Article").class }
check("instantiate symbol keys") { Post.instantiate(id: 97, title: "s").attributes.slice("id", "title") }
check("new attributes") { Post.new(title: "n").attributes.keys }
check("create and read") { r = Post.create!(title: "c", created_at: FIXED, updated_at: FIXED); r2 = Post.find(r.id); [r2.title, r2.status, r2.virtual_n] }
check("includes") { Author.includes(:posts).order(:id).map { |a| a.posts.sort_by(&:id).map(&:title) } }
check("preload sti") { Author.preload(:posts).order(:id).flat_map { |a| a.posts.sort_by(&:id).map(&:class) } }
check("eager_load") { Author.eager_load(:posts).order("authors.id, posts.id").map { |a| [a.name, a.posts.map { [_1.class, _1.title, _1.score] }] } }
check("eager_load partial sti") { Post.eager_load(:comments).order("posts.id").map { |pp| [pp.class, pp.comments.map(&:class)] } }
check("readonly") { Post.readonly.first.readonly? }
check("strict_loading") { Post.strict_loading.first.author }
check("count_by_sql") { Post.count_by_sql("SELECT COUNT(*) FROM posts") }
check("update and reload") { r = Post.find(p1.id); r.update!(title: "u"); Post.find(p1.id).title }
check("insert_all returning") { Post.insert_all([{ title: "ia", created_at: FIXED, updated_at: FIXED }], returning: [:id, :title]).to_a.map { _1.except("id") } }
check("each_attribute via keys") { r = Post.select(:id, :title).first; r.attributes.keys.map { r.read_attribute(_1) } }
check("freeze") { r = Post.find(p1.id).freeze; [r.frozen?, r.title] }
check("hash equality") { Post.find(p1.id) == Post.where(id: p1.id).first }
check("custom discriminate") do
  klass = Class.new(Post) do
    def self.name = "KindPost"
    def self.discriminate_class_for_record(record) = record["kind"] == "k" ? Note : super
  end
  klass.unscoped.order(:id).map(&:class)
end
check("custom instantiate") do
  calls = []
  klass = Class.new(Post) do
    def self.name = "CountingPost"
    define_singleton_method(:instantiate) { |attrs, *rest, &blk| calls << attrs["id"]; super(attrs, *rest, &blk) }
  end
  [klass.unscoped.order(:id).map(&:id).size, calls.size]
end
check("after_find/after_initialize") do
  seen = []
  klass = Class.new(Post) do
    def self.name = "CallbackPost"
    after_find { seen << [:find, title] }
    after_initialize { seen << [:init, title] }
  end
  klass.unscoped.order(:id).limit(2).to_a
  seen
end

# Schema context, table names and primary keys (#59530)
check("primary keys") { [Post.primary_key, Pair.primary_key, Nopk.primary_key, LegacyRow.primary_key] }
check("composite find") { Pair.find([1, 2]).attributes }
check("composite id") { Pair.first.id }
check("no pk first") { Nopk.first.attributes }
check("no pk id") { Nopk.first.id }
check("string pk") { [LegacyRow.find("A1").v, LegacyRow.first.id] }
check("anonymous table") { [Widget.table_name, Widget.first.attributes] }
check("columns") { [Post.column_names, Post.columns_hash.keys == Post.column_names] }
check("attribute_types keys") { Post.attribute_types.keys }
check("sti attribute_types") { Article.attribute_types.keys - Post.attribute_types.keys }
check("type_for_attribute") { [Post.type_for_attribute(:score).type, Post.type_for_attribute(:status).class.name, Post.type_for_attribute(:nope).class.name] }
check("default attributes") { Post._default_attributes.to_hash.slice("status", "published", "virtual_n") }
check("table_name change") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "authors" }
  first = k.first.name
  k.table_name = "widgets"
  [first, k.first.attributes.keys, k.primary_key]
end
check("table_name_prefix") do
  k = Class.new(ActiveRecord::Base) { def self.name = "Thing"; self.table_name_prefix = "wid"; self.table_name_suffix = "s" }
  [k.table_name, (k.first&.attributes&.keys)]
end
check("set primary_key late") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
  k.first
  k.primary_key = "name"
  [k.primary_key, k.find("w").colour, k.first.id]
end
check("pk on subclass") do
  base = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
  sub = Class.new(base) { self.primary_key = "name" }
  [base.primary_key, sub.primary_key, sub.first.id]
end
check("abstract") do
  abs = Class.new(ActiveRecord::Base) { self.abstract_class = true }
  k = Class.new(abs) { self.table_name = "widgets" }
  [abs.table_name, k.table_name, k.count, (abs.columns rescue $!.class)]
end
check("ignored columns") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "posts"; self.ignored_columns = ["body"] }
  [k.column_names.include?("body"), k.first.attributes.keys.include?("body"), (k.first.body rescue $!.class)]
end
check("only columns") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "posts"; self.only_columns = ["id", "title"] }
  [k.column_names, k.first.attributes]
end
check("reset_column_information") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
  k.first
  ActiveRecord::Base.connection.add_column :widgets, :size, :integer, default: 5
  before = k.first.attributes.keys
  k.reset_column_information
  after = k.first.attributes
  ActiveRecord::Base.connection.remove_column :widgets, :size
  k.reset_column_information
  [before, after, k.first.attributes.keys]
end
check("column added, not reset") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
  k.first
  ActiveRecord::Base.connection.add_column :widgets, :size2, :integer, default: 5
  r = k.select("*").first.attributes
  ActiveRecord::Base.connection.remove_column :widgets, :size2
  k.reset_column_information
  r
end
check("column dropped, not reset") do
  ActiveRecord::Base.connection.add_column :widgets, :gone, :string, default: "g"
  k = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
  k.first
  ActiveRecord::Base.connection.remove_column :widgets, :gone
  r = [k.first.attributes, (k.first.gone rescue $!.class)]
  k.reset_column_information
  r
end
check("reorder columns") do
  ActiveRecord::Base.connection.create_table(:swaps, force: true) { |t| t.string :x; t.integer :y }
  k = Class.new(ActiveRecord::Base) { self.table_name = "swaps" }
  k.create!(x: "x", y: 1)
  first = k.first.attributes
  ActiveRecord::Base.connection.create_table(:swaps, force: true) { |t| t.integer :y; t.string :x }
  ActiveRecord::Base.connection.execute("INSERT INTO swaps (id, y, x) VALUES (1, 2, 'z')")
  stale = k.first.attributes
  k.reset_column_information
  [first, stale, k.first.attributes]
end
check("two classes one table") do
  k1 = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
  k2 = Class.new(ActiveRecord::Base) { self.table_name = "widgets"; attribute :colour, :integer }
  [k1.first.colour, k2.first.colour]
end
check("statement cache then table change") do
  k = Class.new(ActiveRecord::Base) { def self.name = "SC"; self.table_name = "authors" }
  k.find(a1.id)
  k.table_name = "posts"
  k.find(p1.id).title
end
check("dup id") { d = Pair.first.dup; [d.a, d.b, d.id] }
check("create returns id") { r = Widget.create!(name: "n2"); [r.id.class, r.persisted?] }
check("sti base_class pk") { [Article.primary_key, Article.base_class, Article.table_name] }
check("inheritance_column override") do
  k = Class.new(ActiveRecord::Base) { def self.name = "KindBase"; self.table_name = "posts"; self.inheritance_column = "kind" }
  [k.inheritance_column, (k.first rescue $!.class)]
end
check("store_full_sti_class") { Article.sti_name }
check("query_constraints") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "posts"; query_constraints :author_id, :id }
  r = k.find_by(id: p1.id)
  r.update!(title: "qc")
  [k.query_constraints_list, k.where(id: p1.id).pick(:title)]
end
