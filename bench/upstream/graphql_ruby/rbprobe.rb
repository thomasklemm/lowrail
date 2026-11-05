require "bundler/setup"; $LOAD_PATH.unshift ARGV[0]; require "graphql"
B = "\uFEFF"
cases = [
  "{ a }", "# c\n{ a }", "{ a # c\n b }", "#only", "# a\n# b\n# c", "{ a }\r# c\r{ b }", "{ a }#c#d\n", "\r\n#x\r\n{ a }",
  "#{B}{ a }", "{#{B}a#{B}}", "{ a }#{B}", "#{B}#{B}, \r\n\t{#{B}a }", "1#{B}field", "{ f(x: 1 # c\n) }",
  "{ f(x: 01) }", "{ f(x: 1.) }", "{ f(x: 1a) }", "query Q($v: Int = 3) { f(a: $v, b: \"s#x\", c: \"\"\"x\n#y\"\"\") }",
  "{ a } extra", "{ a(", "#", "\n\n#\n", "{ a \xEF\xBB }".dup.force_encoding("UTF-8"), "{ \"\\u{1F600}\" }",
  ("# c\n" * 30) + "{ a }", "{ " + ("a # c\n" * 20) + "}",
] + Dir["/tmp/gqq/*.gql"].sort.map { |f| File.read(f) }
cases += Dir["/tmp/gqq/*.gql"].sort.map { |f| File.read(f).gsub("\n", " # note\n") }
cases.each_with_index do |s, i|
  t = begin; GraphQL::Language::Lexer.tokenize(s).map { |x| x.inspect }.join(";"); rescue => e; "LEXERR #{e.class} #{e.message}"; end
  puts "#{i} T #{t}"
  [nil, 3, 5, 12, 40].each do |mt|
    r = begin; d = GraphQL.parse(s, max_tokens: mt); d.to_query_string.bytesize.to_s + d.definitions.map { |x| [x.line, x.col] }.inspect; rescue GraphQL::ParseError => e; "PARSEERR #{e.message} #{[e.line, e.col].inspect}"; end
    puts "#{i} P#{mt.inspect} #{r}"
  end
end
