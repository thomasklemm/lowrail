require "bundler/setup"; $LOAD_PATH.unshift ARGV[0]; require "graphql"; require "graphql/c_parser"
B = "\xEF\xBB\xBF".b.force_encoding("UTF-8")
cases = [
  "#{B}{ a }", "{#{B}a }", " #{B} { a }", "{ a#{B}b }", "{ f(x: 1#{B}) }", "{ f(x: 1#{B}2) }", "{ f(x: 1 #{B}a) }",
  "{ f(x: 1#{B}a) }", "#{B}#{B}#{B}{ a }", "\t#{B},#{B}\t{ a }", "{ a }#{B}", "#{B}", "",
  "{ a \xEF\xBB }", "{ a \xEF }", "{ a \xEF\xBBx }", " \xEF\xBB\xBE{ a }", "{ a\xEF\xBF\xBF }",
  "query Q(#{B}$v: Int = #{B}3) { f(a: $v, b: \"#{B}s\", c: \"\"\"#{B}x\"\"\") }",
  "{ a }\n#{B}  # c#{B}\n{ b } extra", "{ a(b: 1.5#{B}e3) }", "#{B}# only comment", "{ f(x: -#{B}1) }",
  "type T { f: Int }\n#{B}input I #{B}{ x: Float = 1.5e2 }", "{ f(x: 01) }", "{ f(x: 1.) }",
].map { |s| s.dup.force_encoding("UTF-8") }
cases += Dir["/tmp/gqq/*.gql"].sort.map { |f| File.read(f) }
cases += Dir["/tmp/gqq/*.gql"].sort.map { |f| B + File.read(f).gsub(" ", " #{B}") }
[false, true].each do |rnfbn|
  GraphQL.reject_numbers_followed_by_names = rnfbn if GraphQL.respond_to?(:reject_numbers_followed_by_names=)
  cases.each_with_index do |s, i|
    toks = begin; GraphQL::CParser::Lexer.tokenize_with_c_internal(s, false, rnfbn, -1).map(&:inspect).join(";"); rescue => e; "LEXERR #{e.class}: #{e.message} #{e.respond_to?(:line) ? [e.line, e.col] : ''}"; end
    res = begin; d = GraphQL.parse(s); d.to_query_string + " || " + d.definitions.map { |x| [x.line, x.col] }.inspect; rescue GraphQL::ParseError => e; "PARSEERR #{e.message} #{[e.line, e.col].inspect}"; end
    puts "#{rnfbn} #{i} T #{toks}"; puts "#{rnfbn} #{i} P #{res}"
  end
end
