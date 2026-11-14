# Marshal compatibility of Active Record records across two Rails trees. Run with one tree's bundle per phase:
#   BUNDLE_GEMFILE=<A> ruby marshal_compat.rb dump DIR FORMAT   seeds DIR/db.sqlite3, writes DIR/<case>.dump and DIR/expected.json
#   BUNDLE_GEMFILE=<B> ruby marshal_compat.rb load DIR          loads each dump against a copy of the db, reads, saves, reloads
# Prints one line per case: load, attribute reads, association state, save, and whether the reloaded row matches.
require "bundler/setup"
require "active_record"
require "json"
require "fileutils"

mode, dir, version = ARGV
ActiveRecord::Migration.verbose = false
ActiveRecord::Encryption.configure(primary_key: "p" * 32, deterministic_key: "d" * 32, key_derivation_salt: "s" * 32)

def connect(path)
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: path)
end

class Author < ActiveRecord::Base
  has_many :posts
  encrypts :email, deterministic: true
end

class Post < ActiveRecord::Base
  belongs_to :author, optional: true
  has_many :comments
  serialize :meta, coder: JSON
  encrypts :secret
end

class SpecialPost < Post; end

class Comment < ActiveRecord::Base
  belongs_to :post
end

def seed
  ActiveRecord::Schema.define do
    create_table(:authors) { |t| t.string :name; t.string :email }
    create_table(:posts) do |t|
      t.references :author; t.string :type; t.string :title; t.text :meta; t.text :secret; t.integer :views
      t.timestamps
    end
    create_table(:comments) { |t| t.references :post; t.string :body }
  end
  author = Author.create!(name: "ann", email: "ann@example.com")
  8.times do |i|
    klass = i.odd? ? SpecialPost : Post
    post = klass.create!(author: author, title: "post #{i}", meta: { "n" => i }, secret: "s#{i}", views: i)
    post.comments.create!(body: "c#{i}")
  end
end

CASES = {
  "new" => -> { Post.new(title: "new", meta: { "k" => 1 }, secret: "fresh", views: 1) },
  "new_sti" => -> { SpecialPost.new(title: "new sti", meta: { "k" => 2 }, secret: "fresh2") },
  "new_built_assoc" => -> { Post.new(title: "built").tap { |p| p.comments.build(body: "b") } },
  "created" => -> { Post.create!(title: "created", meta: { "k" => 3 }, secret: "made", views: 3) },
  "loaded" => -> { Post.find(1) },
  "loaded_read" => -> { Post.find(3).tap { |p| [p.title, p.meta, p.secret, p.views] } },
  "loaded_dirty" => -> { Post.find(5).tap { |p| p.title = "dirty"; p.meta = { "d" => 1 } } },
  "loaded_sti" => -> { Post.find(2) },
  "includes" => -> { Post.includes(:comments, :author).find(7) },
  "includes_sti" => -> { Post.includes(:comments, :author).find(4) },
  "author_loaded" => -> { Author.includes(:posts).find(1) },
  "partial_select" => -> { Post.select(:id, :title, :type).find(6) },
}

def snapshot(rec)
  h = {
    "class" => rec.class.name, "new" => rec.new_record?, "changed" => rec.changed.sort,
    "attrs" => rec.attributes.transform_values { |v| v.respond_to?(:iso8601) ? v.iso8601 : v },
  }
  rec.class.reflect_on_all_associations.each do |r|
    a = rec.association(r.name)
    h["assoc.#{r.name}"] = [a.loaded?, Array(a.target).map { |t| t.attributes["id"] || t.attributes.values_at("body", "title") }]
  end
  h
end

def compare(want, got)
  want == got ? "same" : "DIFF #{(want.keys | got.keys).reject { |k| want[k] == got[k] }.map { |k| "#{k}: #{want[k].inspect} -> #{got[k].inspect}" }.join("; ")}"
end

def attempt
  [:ok, yield]
rescue Exception => e
  [:err, "#{e.class}: #{e.message.lines.first&.strip&.slice(0, 120)}"]
end

case mode
when "dump"
  FileUtils.mkdir_p(dir)
  db = File.join(dir, "db.sqlite3")
  FileUtils.rm_f(db)
  connect(db)
  seed
  ActiveRecord::Marshalling.format_version = Float(version)
  expected = {}
  CASES.each do |name, build|
    rec = build.call
    File.binwrite(File.join(dir, "#{name}.dump"), Marshal.dump(rec))
    expected[name] = snapshot(rec)
  end
  ActiveRecord::Base.connection_pool.disconnect!
  File.write(File.join(dir, "expected.json"), JSON.pretty_generate("rails" => ActiveRecord.version.to_s, "format" => version, "cases" => expected))
  puts "dumped #{CASES.size} cases with #{ActiveRecord.version} format #{version}"
when "load"
  expected = JSON.parse(File.read(File.join(dir, "expected.json")))
  puts "#{expected["rails"]} format #{expected["format"]} -> #{ActiveRecord.version}"
  CASES.each_key do |name|
    db = File.join(dir, "load-#{name}.sqlite3")
    FileUtils.cp(File.join(dir, "db.sqlite3"), db)
    connect(db)
    status, rec = attempt { Marshal.load(File.binread(File.join(dir, "#{name}.dump"))) }
    if status == :err
      puts format("%-16s load %s", name, rec)
      next
    end
    _, snap = attempt { compare(expected["cases"][name], JSON.parse(JSON.generate(snapshot(rec)))) }
    _, save = attempt do
      rec.title = "#{rec.title} saved" if rec.has_attribute?(:title)
      rec.name = "#{rec.name} saved" if rec.has_attribute?(:name)
      rec.save!
      fresh = rec.class.unscoped.find(rec.id)
      cols = rec.attributes.keys - %w[updated_at]
      fresh.attributes.slice(*cols) == rec.attributes.slice(*cols) ? "saved, row matches" : "saved, ROW DIFF #{fresh.attributes.slice(*cols).reject { |k, v| rec.attributes[k] == v }.keys}"
    end
    puts format("%-16s load ok | state %s | save %s", name, snap, save)
  ensure
    ActiveRecord::Base.connection_pool.disconnect!
  end
end
