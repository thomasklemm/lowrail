require "bundler/setup"; require "graphql"; require "graphql/c_parser"
src = File.read(ARGV[0]); n = Integer(ARGV[1])
3.times { 100.times { GraphQL.parse src } }
GC.start
n.times { 100.times { GraphQL.parse src } }
