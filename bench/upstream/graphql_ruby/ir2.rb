# ir2.rb <c_parser lib dir> <query file> <iterations> [check]
require "bundler/setup"
$LOAD_PATH.unshift ARGV[0]
require "graphql"; require "graphql/c_parser"
abort "wrong ext" unless $LOADED_FEATURES.grep(/graphql_c_parser_ext/).all? { |f| f.start_with?(ARGV[0]) }
src = File.read(ARGV[1]); n = Integer(ARGV[2])
if ARGV[3]
  puts "#{GraphQL::CParser::VERSION} #{$LOADED_FEATURES.grep(/graphql_c_parser_ext/).first}"
  exit
end
3.times { 100.times { GraphQL.parse src } }
GC.start
n.times { 100.times { GraphQL.parse src } }
