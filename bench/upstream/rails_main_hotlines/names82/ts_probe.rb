# RAILS_PATH=TREE ruby ts_probe.rb: differential probe for the private timestamp_attributes_for_create/update fix.
# Every way an app or gem overrides or calls the two hooks, on 8.1.4.1, main and the branch.
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
  create_table(:posts) { |t| t.string :title; t.string :type; t.timestamps null: true; t.datetime :created_on; t.datetime :updated_on; t.datetime :extra_at; t.datetime :created; t.datetime :modified }
end
puts "Active Record #{ActiveRecord.version}"
$n = 0
def model(parent = ActiveRecord::Base, &block)
  Class.new(parent) do
    self.table_name = "posts" unless parent.respond_to?(:abstract_class?) && !parent.abstract_class? && parent != ActiveRecord::Base
    define_singleton_method(:name) { "Post#{$n += 1}" }
    class_eval(&block) if block
  end
end
def set(r) = %w[created_at updated_at created_on updated_on extra_at created modified].select { r[_1] }
def life(m)
  r = m.create!(title: "a")
  c = set(r)
  r.update_columns(created_at: nil, updated_at: nil, created_on: nil, updated_on: nil, extra_at: nil, created: nil, modified: nil)
  r.update!(title: "b")
  "create=#{c.join(",")} update=#{set(r).join(",")}"
end
def run(label)
  puts "#{label} => #{yield}"
rescue Exception => e
  puts "#{label} => #{e.class}: #{e.message.lines.first.strip.sub(/#<Class:0x\h+>|Post\d+/, "M")}"
end

run("no override") { life(model) }
run("public def self. create + super") { life(model { def self.timestamp_attributes_for_create = super + ["extra_at"] }) }
run("public def self. update + super") { life(model { def self.timestamp_attributes_for_update = super + ["extra_at"] }) }
run("class << self; private create") { life(model { class << self; private def timestamp_attributes_for_create = super + ["extra_at"]; end }) }
run("class << self; private update") { life(model { class << self; private def timestamp_attributes_for_update = super + ["extra_at"]; end }) }
run("class << self; protected create") { life(model { class << self; protected def timestamp_attributes_for_create = super + ["extra_at"]; end }) }
run("concern class_methods private, replace both (postfix_admin)") do
  mod = Module.new { extend ActiveSupport::Concern; class_methods { private; def timestamp_attributes_for_create = ["created"]; def timestamp_attributes_for_update = ["modified"] } }
  life(model { include mod })
end
run("concern class_methods public, replace both") do
  mod = Module.new { extend ActiveSupport::Concern; class_methods { def timestamp_attributes_for_create = ["created"]; def timestamp_attributes_for_update = ["modified"] } }
  life(model { include mod })
end
run("private override on abstract parent (trefle-api), child model") do
  parent = Class.new(ActiveRecord::Base) { self.abstract_class = true; class << self; private def timestamp_attributes_for_create = super << "extra_at"; end }
  life(Class.new(parent) { self.table_name = "posts"; def self.name = "Child#{$n += 1}" })
end
run("private override on STI base, subclass") do
  base = model { class << self; private def timestamp_attributes_for_update = super + ["extra_at"]; end }
  sub = Class.new(base) { def self.name = "#{superclass.name}Sub" }
  life(sub)
end
run("extend with a private module method") do
  life(model { extend(Module.new { private def timestamp_attributes_for_update = ["modified"] }) })
end
run("prepend to singleton, private, calls super") do
  life(model { singleton_class.prepend(Module.new { private def timestamp_attributes_for_create = super + ["extra_at"] }) })
end
run("alias_attribute :created_on_alias -> attribute_aliases honoured") { life(model { alias_attribute :made_at, :extra_at; def self.timestamp_attributes_for_create = super + ["made_at"] }) }
run("Model.timestamp_attributes_for_create (public call)") { model.timestamp_attributes_for_create.inspect }
run("Model.respond_to?(:timestamp_attributes_for_update)") { model.respond_to?(:timestamp_attributes_for_update).inspect }
run("Model.send(:timestamp_attributes_for_update)") { model.send(:timestamp_attributes_for_update).inspect }
run("Model.private_methods.include?(:timestamp_attributes_for_create)") { model.private_methods.include?(:timestamp_attributes_for_create).inspect }
run("touch and touch(:extra_at)") { r = model.create!(title: "t"); r.update_columns(updated_at: nil, extra_at: nil); r.touch(:extra_at); set(r).join(",") }
run("insert_all record_timestamps") { m = model; m.insert_all([{ title: "i" }]); set(m.last).join(",") }
run("reset_column_information then private override still used") do
  m = model { class << self; private def timestamp_attributes_for_create = super + ["extra_at"]; end }
  m.create!(title: "x"); m.reset_column_information; life(m)
end
