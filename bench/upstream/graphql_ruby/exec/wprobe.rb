# Differential probe for Warden name caches: results, errors and visible? hook call counts.
require "graphql"
require "graphql/c_parser" if ENV["CP"]
require "json"
$calls = Hash.new(0)
module Counted
  def visible?(ctx) = ($calls["#{self.class.name}:#{respond_to?(:path) ? path : graphql_name}"] += 1; super)
end
class BaseField < GraphQL::Schema::Field
  include Counted
  def visible?(ctx) = ($calls["field:#{path}"] += 1; !(ctx[:hide] && graphql_name == "secret"))
end
class BaseObject < GraphQL::Schema::Object
  field_class BaseField
  def self.visible?(ctx) = ($calls["type:#{graphql_name}"] += 1; !(ctx[:hide_type] && graphql_name == "Hidden"))
end
module Named
  include GraphQL::Schema::Interface
  field_class BaseField
  field :name, String
  field :secret, String
  def self.visible?(ctx) = ($calls["iface:Named"] += 1; super)
end
class Hidden < BaseObject
  field :x, Int
  def x = 1
end
class Thing < BaseObject
  implements Named
  field :id, ID
  field :secret, String
  field :hidden, Hidden
  field :child, Thing
  field :things, [Thing]
  def name = "n#{object}"
  def id = object.to_s
  def secret = "s"
  def hidden = 1
  def child = object + 1
  def things = [object, object + 1]
end
class Query < BaseObject
  field :thing, Thing
  field :node, Named
  field :secret, String
  def thing = 1
  def node = 2
  def secret = "q"
end
class Schema < GraphQL::Schema
  query Query
  def self.resolve_type(*) = Thing
end
Schema.use_visibility_profile = false if Schema.respond_to?(:use_visibility_profile=)
docs = [
  "{ thing { id id name secret child { id name child { name secret } } things { id name secret } } }",
  "{ thing { ...F ...F things { ...F } } node { name secret ... on Thing { id secret } } } fragment F on Thing { id name secret hidden { x } }",
  "{ secret thing { nope secret } nope }",
  "{ thing { hidden { x } } a: thing { hidden { x y } } }",
  "query { node { ... on Hidden { x } ... on Thing { name } } }",
  "{ __typename thing { __typename name } __type(name: \"Thing\") { fields { name } } }",
  "{ thing { secret: name name: secret } }",
]
ctxs = [{}, { hide: true }, { hide_type: true }, { hide: true, hide_type: true }]
out = []
docs.each do |d|
  ctxs.each do |c|
    $calls.clear
    r = Schema.execute(d, context: c).to_h
    v = Schema.validate(d, context: c).map(&:to_h)
    w = (q = GraphQL::Query.new(Schema, d, context: c); q.static_errors; [q.types.type("Thing")&.graphql_name, q.types.type("Hidden")&.graphql_name, q.types.field(Schema.query, "secret")&.path, q.types.field(Schema.query, +"secret")&.path])
    out << { d:, c:, r:, v:, w:, calls: $calls.sort.to_h }
  end
end
puts JSON.pretty_generate(out)
