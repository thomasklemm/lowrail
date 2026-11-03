require "objspace"
class Intent; def initialize; 14.times { instance_variable_set(:"@i#{_1}", _1) }; end; end
class Intent6; def initialize; 6.times { instance_variable_set(:"@i#{_1}", _1) }; end; end
2.times { Intent.new; Intent6.new }
re = Regexp.new("^#{Regexp.escape("localhost")}$", Regexp::IGNORECASE)
md = "localhost".match(/(\w+)(o)(s)/)
rows = {
  "Object 14 ivars" => Intent.new, "Object 6 ivars" => Intent6.new,
  "Regexp.new (cookie_jar:97)" => re, "MatchData 3 groups" => md, "MatchData 0 groups" => "abc".match(/b/),
  'String.new("")' => String.new(""), "String.new(100 B)" => String.new("x" * 100), "String.new(capacity: 1000)" => String.new(capacity: 1000),
  "OutputBuffer-like encode!" => String.new("").tap(&:encode!),
}
rows.each { |n, o| printf("%-28s %5d\n", n, ObjectSpace.memsize_of(o)) }
