require "graphql"
require "json"
$log = []
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
    $log << "Thing.get_field(#{name}) staff=#{context[:staff].inspect}"
    if name == "staffName" && !context[:staff]
      super("alt", context)   # documented pattern: pick a different definition per context
    else
      super
    end
  end
end
class Query < GraphQL::Schema::Object
  field :node, Named
  field :drop_staff, Boolean
  def node = 1
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
[
  "{ a: node { staffName } dropStaff b: node { staffName } }",
  "{ a: node { ... on Named { staffName } } dropStaff b: node { ... on Named { staffName } } }",
].each do |d|
  $log.clear
  r = begin; Schema.execute(d, context: { staff: true }).to_h; rescue => e; "#{e.class}: #{e.message[0,200]}"; end
  puts JSON.generate(d: d, r: r, log: $log)
end
