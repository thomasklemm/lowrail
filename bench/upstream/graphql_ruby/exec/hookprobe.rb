require "graphql"
require "json"
$log = []

class Thing < GraphQL::Schema::Object
  field :name, String
  field :staff_name, String
  def name = "n"
  def staff_name = "staff"
  # Documented hook (guides/schema/dynamic_types.md): .get_field(name, context)
  def self.get_field(name, context = GraphQL::Query::NullContext.instance)
    $log << "Thing.get_field(#{name}) staff=#{context[:staff].inspect}"
    if name == "staffName" && !context[:staff]
      nil
    else
      super
    end
  end
end

class Query < GraphQL::Schema::Object
  field :thing, Thing
  field :become_staff, Boolean
  def thing = 1
  def become_staff
    context[:staff] = true
    true
  end
end

class Schema < GraphQL::Schema
  query Query
  def self.get_type(name, context = null_context, use_vp = use_visibility_profile?)
    $log << "Schema.get_type(#{name})" if name == "Thing"
    super
  end
end

docs = [
  # staffName is re-looked-up at runtime in a later node after context mutated
  "{ a: thing { name } becomeStaff b: thing { name } }",
  "{ a: thing { name } b: thing { name } c: thing { name } }",
  "{ thing { ...F } } fragment F on Thing { name }",
]
docs.each do |d|
  $log.clear
  r = Schema.execute(d, context: {}).to_h
  puts JSON.generate(d: d, r: r, calls: $log.size, log: $log.tally)
end

# Type condition lookups by name: __type(name:) with mutated context
$log.clear
q = GraphQL::Query.new(Schema, "{ thing { name } }")
q.static_errors
p [:get_type_calls_after_validate, $log.size]
q.types.type(+"Thing"); q.types.type(+"Thing")
p [:get_type_calls_after_2_more, $log.size]
q.context[:staff] = true
p [:field_after_ctx_mutation, q.types.field(Thing, +"staffName")&.path]
q2 = GraphQL::Query.new(Schema, "{ thing { name } }")
p [:fresh_field_before, q2.types.field(Thing, +"staffName")&.path]
q2.context[:staff] = true
p [:fresh_field_after_mutation_new_string, q2.types.field(Thing, +"staffName")&.path]
p [:fresh_field_after_mutation_same_literal, q2.types.field(Thing, "staffName")&.path]
