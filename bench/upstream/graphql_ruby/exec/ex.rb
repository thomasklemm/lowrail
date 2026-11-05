# usage: ex.rb SCENARIO N  (run from graphql-ruby root); GRAPHQL_FUTURE=1 for track scenarios
$LOAD_PATH << "./lib" << "./spec/support"
require File.expand_path("benchmark/run.rb")
include GraphQLBenchmark
next_s = ->(s) { Class.new(s) { use(GraphQL::Execution::Next) } }
EXEC = next_s.(SCHEMA)
SMALL = next_s.(SILLY_LARGE_SCHEMA)
S = {
  "parse_intro" => -> { GraphQL.parse(QUERY_STRING) },
  "parse_big" => -> { GraphQL.parse(BIG_QUERY_STRING) },
  "val_abstract" => -> { CARD_SCHEMA.validate(ABSTRACT_FRAGMENTS) },
  "val_abstract2" => -> { CARD_SCHEMA.validate(ABSTRACT_FRAGMENTS_2) },
  "val_intro" => -> { CARD_SCHEMA.validate(DOCUMENT) },
  "val_big" => -> { BIG_SCHEMA.validate(BIG_QUERY) },
  "val_merge" => -> { FIELDS_WILL_MERGE_SCHEMA.validate(FIELDS_WILL_MERGE_QUERY) },
  "next_intro" => -> { EXEC.execute_next(document: DOCUMENT) },
  "next_small" => -> { SMALL.execute_next("{ __typename }") },
  "next_large" => -> { ProfileLargeResult::Schema.execute_next(document: ProfileLargeResult::ALL_FIELDS) },
  "int_intro" => -> { SCHEMA.execute(document: DOCUMENT) },
  "int_small" => -> { SILLY_LARGE_SCHEMA.execute("{ __typename }") },
  "int_large" => -> { ProfileLargeResult::Schema.execute(document: ProfileLargeResult::ALL_FIELDS) },
}
name, n = ARGV[0], Integer(ARGV[1])
blk = S.fetch(name)
out = nil
3.times { out = blk.() }
if ENV["DUMP"]
  File.write(ENV["DUMP"], (out.respond_to?(:to_h) ? out.to_h : out).inspect)
end
GC.start
n.times { blk.() }
