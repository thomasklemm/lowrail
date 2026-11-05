# Version-portable workloads (graphql 2.5.x .. master), classic APIs only.
# usage: ruby -I<lib> ver.rb SCENARIO N   (DUMP=path writes the last result)
require "graphql"
require "json"
B = "/tmp/gr/benchmark"
CARD = GraphQL::Schema.from_definition(File.read("#{B}/schema.graphql"))
ABS2 = GraphQL.parse(File.read("#{B}/abstract_fragments_2.graphql"))
ABS = GraphQL.parse(File.read("#{B}/abstract_fragments.graphql"))
BIGS = GraphQL::Schema.from_definition(File.read("#{B}/big_schema.graphql"))
BIGQ = GraphQL.parse(File.read("#{B}/big_query.graphql"))
INTRO = GraphQL.parse(GraphQL::Introspection::INTROSPECTION_QUERY)

module LR
  DATA = Array.new(500) { |i| { id: "id#{i}", int1: i, int2: i * 7, string1: "s#{i}", string2: "t#{i}",
    boolean1: i.even?, boolean2: i.odd?, int_array: Array.new(10) { _1 + i }, string_array: Array.new(10) { "a#{_1}" } } }
  module Named
    include GraphQL::Schema::Interface
    field :id, GraphQL::Types::ID, null: false
  end
  class Foo < GraphQL::Schema::Object
    implements Named
    field :int1, Integer, null: false
    field :int2, Integer, null: false, hash_key: :int2
    field :string1, String, null: false do
      argument :arg1, String, required: false
    end
    def string1(arg1: nil) = object[:string1]
    field :string2, String, null: false
    field :boolean1, Boolean, null: false
    field :boolean2, Boolean, null: false
    field :int_array, [Integer], null: false
    field :string_array, [String], null: false
    def int1 = object[:int1]
    def id = object[:id]
    def string2 = object[:string2]
    def boolean1 = object[:boolean1]
    def boolean2 = object[:boolean2]
    def int_array = object[:int_array]
    def string_array = object[:string_array]
  end
  class Query < GraphQL::Schema::Object
    field :foos, [Foo], null: false do
      argument :first, Integer, required: false, default_value: 500
    end
    def foos(first:) = DATA.first(first)
    field :node, Named do
      argument :id, GraphQL::Types::ID
    end
    def node(id:) = DATA[id.delete_prefix("id").to_i]
  end
  class Schema < GraphQL::Schema
    query Query
    def self.resolve_type(_t, _o, _c) = Foo
  end
  DOC = GraphQL.parse(<<~Q)
    query($skip: Boolean = false) { foos { id @skip(if: $skip) int1 int2 string1(arg1: "x") string2 boolean1 boolean2 intArray stringArray } }
  Q
  SMALL = GraphQL.parse(<<~Q)
    query Q($id: ID!) { a: node(id: $id) { id ... on Foo { int1 string1 } } b: node(id: "id3") { __typename id } foos(first: 3) { ...F } }
    fragment F on Foo { id int2 boolean1 }
  Q
end

S = {
  "parse_intro" => -> { GraphQL.parse(GraphQL::Introspection::INTROSPECTION_QUERY) },
  "val_abs2" => -> { CARD.validate(ABS2) },
  "val_abs" => -> { CARD.validate(ABS) },
  "val_big" => -> { BIGS.validate(BIGQ) },
  "val_intro" => -> { CARD.validate(INTRO) },
  "exe_intro_big" => -> { BIGS.execute(document: INTRO).to_h },
  "exe_large" => -> { LR::Schema.execute(document: LR::DOC).to_h },
  "exe_small" => -> { LR::Schema.execute(document: LR::SMALL, variables: { "id" => "id5" }).to_h },
}
name, n = ARGV[0], Integer(ARGV[1])
blk = S.fetch(name)
out = nil
3.times { out = blk.() }
File.write(ENV["DUMP"], JSON.pretty_generate(out.is_a?(Array) ? out.map { _1.respond_to?(:to_h) ? _1.to_h : _1.inspect } : out)) if ENV["DUMP"]
GC.start
n.times { blk.() }
