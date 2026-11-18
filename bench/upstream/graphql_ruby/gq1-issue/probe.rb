require "graphql"
require "json"

# Same lookups as Warden#get_type and #get_field, but the name Hash compares by value.
module CacheByName
  def get_type(type_name)
    @types_by_name ||= Hash.new do |h, name|
      type_defn = @schema.get_type(name, @context, false)
      h[name] = type_defn && visible_and_reachable_type?(type_defn) ? type_defn : nil
    end
    @types_by_name[type_name]
  end

  def get_field(parent_type, field_name)
    @fields_by_name ||= Hash.new do |h, type|
      h[type] = Hash.new do |h2, name|
        field_defn = @schema.get_field(type, name, @context)
        h2[name] = field_defn && visible_field?(field_defn, nil, type) ? field_defn : nil
      end
    end.compare_by_identity
    @fields_by_name[parent_type][field_name]
  end
end

$calls = Hash.new(0)

module Named
  include GraphQL::Schema::Interface
  field :staff_name, String
end

class Thing < GraphQL::Schema::Object
  implements Named
  field :alt, String
  def staff_name = "staff"
  def alt = "alt"

  def self.get_field(name, context = GraphQL::Query::NullContext.instance)
    $calls[name] += 1
    if name == "staffName" && !context[:staff]
      super("alt", context)
    else
      super
    end
  end
end

class Query < GraphQL::Schema::Object
  field :node, Named
  field :thing, Thing
  field :drop_staff, Boolean
  def node = 1
  def thing = 1

  def drop_staff
    context[:staff] = false
    true
  end
end

class Schema < GraphQL::Schema
  query Query
  orphan_types Thing
  def self.resolve_type(*) = Thing
end

big = GraphQL.parse("{ thing { #{(["alt"] * 5000).join(" ")} } }")
changing = "{ a: node { staffName } dropStaff b: node { staffName } }"

def run(label, big, changing)
  $calls.clear
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  5.times { Schema.validate(big) }
  ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000 / 5
  puts "#{label}:"
  puts "  validate 5000 x alt: Thing.get_field called #{$calls["alt"] / 5} times, #{ms.round(1)} ms"
  $calls.clear
  puts "  #{JSON.generate(Schema.execute(changing, context: { staff: true })["data"])}"
  puts "  Thing.get_field(\"staffName\") called #{$calls["staffName"]} times"
end

puts "graphql #{GraphQL::VERSION}, Ruby #{RUBY_VERSION}"
run("as released", big, changing)
GraphQL::Schema::Warden.prepend(CacheByName)
run("names cached by value", big, changing)
