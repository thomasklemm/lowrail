require "graphql"
require "json"

class ReviewField < GraphQL::Schema::Field
  def initialize(*args, restricted: false, **kwargs, &block)
    @restricted = restricted
    super(*args, **kwargs, &block)
  end

  def visible?(ctx)
    super && (!@restricted || ctx[:staff])
  end
end

class ReviewThing < GraphQL::Schema::Object
  graphql_name "Thing"
  field_class ReviewField
  field :name, String
  field :other, String
  field :secret, String, restricted: true
  def name = "name"
  def other = "other"
  def secret = "secret"

  def self.get_field(name, ctx = GraphQL::Query::NullContext.instance)
    (ctx[:field_calls] ||= []) << name.to_s
    return nil if ctx[:deny] && name == "name"
    super
  end
end

class ReviewRoot < GraphQL::Schema::Object
  field :thing, ReviewThing
  field :hide_type, Boolean
  def thing = 1
  def hide_type
    context[:deny_type] = true
    true
  end
end

class ReviewSchema < GraphQL::Schema
  query ReviewRoot
  use GraphQL::Schema::Warden
  def self.get_type(name, ctx = null_context, vp = use_visibility_profile?)
    (ctx[:type_calls] ||= []) << name.to_s
    return nil if ctx[:deny_type] && name == "Thing"
    super
  end
end
ReviewSchema.use(GraphQL::Schema::Visibility) if ENV["PROFILE"]

def query(ctx = {})
  GraphQL::Query.new(ReviewSchema, "{ __typename }", context: ctx)
end

def emit(label, value)
  puts JSON.generate(label: label, value: value)
end

emit("default", [GraphQL::Schema.use_visibility_profile?, query.warden.class.name])
[:deny, :deny_type].each do |key|
  [false, true].each do |before|
    q = query(key => before)
    lookup = -> { key == :deny ? q.types.field(ReviewThing, +"name")&.path : q.types.type(+"Thing")&.graphql_name }
    first = lookup.call
    q.context[key] = !before
    emit("#{key}:#{before}->#{!before}", [first, lookup.call, q.context[:field_calls], q.context[:type_calls]])
  end
end

plain_subclass = Class.new(String)
duck = Object.new
def duck.to_str = "name"
[+"name", "name".freeze, plain_subclass.new("name"), :name, duck].each_with_index do |name, index|
  q = query
  field = q.types.field(ReviewThing, name)
  emit("name_kind_#{index}", [field&.path, name.frozen?])
end
q = query
name = +"name"
first = q.types.field(ReviewThing, name)&.path
name.replace("other")
emit("mutated_field_string", [first, q.types.field(ReviewThing, name)&.path, q.types.field(ReviewThing, +"name")&.path, name.frozen?])
q = query
name = +"Thing"
first = q.types.type(name)&.graphql_name
name.replace("String")
emit("mutated_type_string", [first, q.types.type(name)&.graphql_name, q.types.type(+"Thing")&.graphql_name, name.frozen?])
q = query
emit("symbol_then_string", [q.types.type(:Thing)&.graphql_name, q.types.type("Thing")&.graphql_name, q.types.field(ReviewThing, :name)&.path, q.types.field(ReviewThing, "name")&.path])

q = query(staff: true)
first = q.types.field(ReviewThing, +"secret")&.path
q.context[:staff] = false
emit("visible_hook_already_memoized", [first, q.types.field(ReviewThing, +"secret")&.path])

doc = "{ thing { name secret } }"
emit("multiplex", ReviewSchema.multiplex([
  { query: doc, context: { staff: true } },
  { query: doc, context: { staff: false } },
  { query: doc, context: { staff: true } }
]).map(&:to_h))

emit("type_override_execution", ReviewSchema.execute('{ a: __type(name: "Thing") { name } hideType b: __type(name: "Thing") { name } }').to_h)

unless ENV["PROFILE"]
  ctx = { deny: false }
  shared = GraphQL::Schema::Warden.new(schema: ReviewSchema, context: ctx)
  first = GraphQL::Query.new(ReviewSchema, "{ __typename }", warden: shared).types.field(ReviewThing, +"name")&.path
  ctx[:deny] = true
  second = GraphQL::Query.new(ReviewSchema, "{ __typename }", warden: shared).types.field(ReviewThing, +"name")&.path
  emit("explicit_shared_warden", [first, second])
end
