# Differential for resolve_attribute_name: run in main and in the candidate, compare the printed digest.
require "bundler/setup"
require_relative "setup"
require "digest"

class Named
  def initialize(s) = @s = s
  def to_s = @s
  def inspect = "Named(#{@s})"
end
class SubStr < String; end

class Base1 < ActiveRecord::Base
  self.table_name = "posts"
  alias_attribute :headline, :title
  alias_attribute :created, :created_at
end
class Child1 < Base1
  alias_attribute :content, :body
end
class Form
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :name, :string
  attribute :at, :datetime
  alias_attribute :label, :name
end
class Form2 < Form
  alias_attribute :when, :at
end

out = []
names = [:title, "title", "title".freeze, :headline, "headline", :created, "created", :content, "content", :body,
  :nope, "nope", "", :"", SubStr.new("headline"), SubStr.new("title"), Named.new("headline"), Named.new("x"),
  :label, "label", :name, :when, "when", :at, 1, nil]
[Post, Base1, Child1, Form, Form2].each do |k|
  names.each do |n|
    r = begin
      v = k.send(:resolve_attribute_name, n)
      [v, v.class, v.frozen?, v.encoding.name]
    rescue Exception => e
      [e.class, e.message]
    end
    t = begin
      k.type_for_attribute(n).class
    rescue Exception => e
      [e.class, e.message]
    end
    tb = begin
      k.type_for_attribute(n) { |x| [:missing, x, x.class] }
    rescue Exception => e
      [e.class, e.message]
    end
    tb = tb.class unless tb.is_a?(Array)
    out << [k.name, n.inspect, r, t, tb]
  end
end
# identity: is the returned String the alias table's own value when aliased?
out << [Base1.send(:resolve_attribute_name, "headline").equal?(Base1.attribute_aliases["headline"])]
# the String returned for an unaliased String argument: same object as the argument?
s = +"title"; out << [Post.send(:resolve_attribute_name, s).equal?(s)]
# runtime alias added later, and a subclass created before the alias
class Late < ActiveRecord::Base; self.table_name = "posts"; end
class LateChild < Late; end
Late.alias_attribute :heading, :title
out << [Late.send(:resolve_attribute_name, :heading), LateChild.send(:resolve_attribute_name, :heading)]
# records: read/write through aliases, where with aliases
r = Child1.create!(headline: "h", content: "c")
out << [r.headline, r.title, r.content, Child1.where(headline: "h").count, Child1.where(content: "c").to_sql]
out << [Form2.new(label: "l", when: "2026-01-01 10:00").attributes.transform_values(&:to_s)]
File.write(ENV.fetch("OUT"), out.map(&:inspect).join("\n"))
puts out.size
out.first(3).each { p _1 } if ENV["SHOW"]
