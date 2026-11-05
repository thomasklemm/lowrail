require "graphql"
s = GraphQL::Schema.from_definition("type Query { hello: String }")
d = GraphQL.parse("{ hello hello hello }")
names = d.definitions[0].selections.map(&:name)
p names.map(&:object_id).uniq.size, names.map(&:frozen?)
calls = 0
GraphQL::Schema.singleton_class.prepend(Module.new { define_method(:get_field) { |*a, **k| calls += 1; super(*a, **k) } })
s.validate(d)
p calls
