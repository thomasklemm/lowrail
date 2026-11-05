require "bundler/setup"; require "graphql"; require "graphql/c_parser"; require "digest"
src = File.read(ARGV[0])
doc = GraphQL.parse(src)
out = []
walk = ->(n, d) {
  vals = n.class.instance_method(:scalars) rescue nil
  sc = n.respond_to?(:scalars) ? n.scalars.map(&:inspect).join(",") : ""
  out << "#{"  " * d}#{n.class.name.split("::").last} #{n.line}:#{n.col} #{sc}"
  n.children.each { |c| walk.(c, d + 1) }
}
walk.(doc, 0)
puts "parser=#{GraphQL.default_parser} c_parser=#{GraphQL::CParser::VERSION} graphql=#{GraphQL::VERSION}"
puts "nodes=#{out.size} tree=#{Digest::SHA256.hexdigest(out.join("\n"))[0,16]} query_string=#{Digest::SHA256.hexdigest(doc.to_query_string)[0,16]} tokens=#{GraphQL::CParser::Lexer.tokenize_with_c_internal(src, false, false, -1).size}"
File.write(ARGV[1], out.join("\n"))
