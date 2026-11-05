# ir3.rb <graphql lib dir> <n> [check]  -- pure-Ruby parser over four fixed documents
require "bundler/setup"
$LOAD_PATH.unshift ARGV[0]
require "graphql"
abort "wrong graphql #{$LOADED_FEATURES.grep(%r{/graphql\.rb$}).inspect}" unless $LOADED_FEATURES.grep(%r{/graphql\.rb$}).all? { |f| f.start_with?(ARGV[0]) }
abort "c parser loaded" if defined?(GraphQL::CParser)
DOCS = { "negotiate" => 2, "big_query" => 20, "introspection" => 100, "mutation" => 200 }.map { |k, reps| [k, File.read("/tmp/gqq/#{k}.gql"), reps] }
only = ENV["ONLY"]
docs = only ? DOCS.select { |k, _, _| k == only } : DOCS
if ARGV[2]
  puts "#{GraphQL::VERSION} #{GraphQL.default_parser}"
  docs.each { |k, s, _| d = GraphQL.parse(s); puts "#{k} #{d.to_query_string.bytesize}" }
  exit
end
n = Integer(ARGV[1])
run = -> { docs.each { |_, s, reps| reps.times { GraphQL.parse(s) } } }
3.times { run.() }
GC.start
n.times { run.() }
