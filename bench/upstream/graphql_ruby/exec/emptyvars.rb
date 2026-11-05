require "graphql"; require "graphql/c_parser"
["mutation() { a }", "query () { a }", "query Q() { a }", "query Q($a: Int) { a }"].each do |s|
  r = [GraphQL::Language::Parser, GraphQL::CParser].map { |p| (p.parse(s); "ok") rescue "#{$!.class}: #{$!.message[0, 60]}" }
  puts "#{s.inspect}: ruby #{r[0]} | c #{r[1]}"
end
