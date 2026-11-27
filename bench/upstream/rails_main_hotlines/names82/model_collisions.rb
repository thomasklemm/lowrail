# RAILS_PATH=TREE ruby model_collisions.rb: each model-side name collision from names.txt, run as an app would write it.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  if (path = ENV["RAILS_PATH"])
    %w[activesupport activemodel activerecord].each { gem _1, path: "#{path}/#{_1}" }
  else
    gem "activerecord", ENV.fetch("AR_VERSION", "8.1.4.1")
  end
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :status, default: 0; t.datetime :created_at; t.datetime :updated_at; t.datetime :published_at; t.datetime :edited_at }
end
puts "Active Record #{ActiveRecord.version}"
$n = 0
def model(&block)
  Class.new(ActiveRecord::Base) do
    self.table_name = "posts"
    define_singleton_method(:name) { "Post#{$n += 1}" }
    class_eval(&block)
  end
end
def run(label)
  puts "#{label} => #{yield.inspect}"
rescue Exception => e
  puts "#{label} => #{e.class}: #{e.message.lines.first.strip}"
end

puts "\n## timestamp_attributes_for_create/update overridden as private class methods (Rails' own visibility up to 8.1)"
run("private override: create sets published_at, update sets edited_at") do
  m = model do
    class << self
      private
        def timestamp_attributes_for_create = super + ["published_at"]
        def timestamp_attributes_for_update = super + ["edited_at"]
    end
  end
  r = m.create!(title: "a")
  set_on_create = !r.published_at.nil?
  r.update!(title: "b")
  [set_on_create, !r.edited_at.nil?]
end
run("public override (def self.)") do
  m = model do
    def self.timestamp_attributes_for_create = super + ["published_at"]
  end
  !m.create!(title: "a").published_at.nil?
end

puts "\n## type_for_column(connection, column) overridden as in Rails up to 8.1"
run("private override with (connection, column)") do
  m = model do
    class << self
      private
        def type_for_column(connection, column)
          column.name == "title" ? ActiveModel::Type::String.new(limit: 3) : super
        end
    end
  end
  m.new(title: "abcdef").title
end

puts "\n## Private ActiveModel::Serialization#serialization_key overridden by a model method of the same name"
run("def serialization_key (no args); as_json(only: :title)") do
  m = model { def serialization_key = "post-#{id}" }
  m.create!(title: "a").as_json(only: :title)
end
run("def serialization_key (no args); as_json") do
  m = model { def serialization_key = "post-#{id}" }
  m.create!(title: "a").as_json.keys.first(2)
end
run("def serialization_key(name) returning something else; as_json(methods: :foo)") do
  m = model { def serialization_key(_) = "k"; def foo = 1 }
  m.create!(title: "a").as_json(only: :title, methods: :foo)
end

puts "\n## Scopes, class methods and enum values with the new model class method names"
%w[has_json has_delegated_json schema_context schema_attributes mapped_table all_queries_scope attribute_slots abstract_ancestors primary_key_definition].each do |name|
  run("scope :#{name}") { model { scope name, -> { where(nil) } }; "defined" }
end
%w[schema_attributes mapped_table schema_context attribute_slots abstract_ancestors primary_key_definition has_default_scope? current_schema_context].each do |name|
  run("def self.#{name} (app's own, no args) then create/find") do
    m = model { define_singleton_method(name) { "app" } }
    m.create!(title: "a"); m.where(title: "a").count
  end
end
run("enum :status, [:draft, :schema_context]") { model { enum :status, [:draft, :schema_context] }; "defined" }

puts "\n## Columns or associations with the new instance method names"
%w[read_attr resolve_alias serialization_key association_cache].each do |name|
  run("dangerous_attribute_method?(:#{name})") { ActiveRecord::Base.dangerous_attribute_method?(name) }
end
