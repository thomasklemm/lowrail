require "graphql"
require "benchmark"
class ReviewSizeRoot < GraphQL::Schema::Object
  field :name, String
end
class ReviewSizeSchema < GraphQL::Schema
  query ReviewSizeRoot
end
[8, 64, 1024, 1024 * 1024].each do |size|
  name = "z" * size
  types = GraphQL::Query.new(ReviewSizeSchema, "{ __typename }").types
  types.field(ReviewSizeRoot, name)
  times = Array.new(2) { Benchmark.realtime { 1000.times { types.field(ReviewSizeRoot, name) } } }
  puts "#{size} bytes: #{times.map { |t| '%.6f' % t }.join(' / ')} seconds per 1000 cached missing-field lookups"
end
