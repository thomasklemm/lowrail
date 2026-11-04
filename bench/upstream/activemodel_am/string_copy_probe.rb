# frozen_string_literal: true
def a(v) = ::String.new(v)
def b(v) = v.instance_of?(::String) ? v.dup : ::String.new(v)
class Sub < String; end
cases = {
  "plain" => +"abc", "frozen" => "abc", "fstr" => -"abc", "empty" => +"", "binary" => "\xFF".b,
  "utf16" => "hi".encode("UTF-16LE"), "invalid" => +"\xFFabc", "long" => "x" * 5000,
  "sub" => Sub.new("x"), "safebuf" => nil,
  "ivar" => (+"iv").tap { _1.instance_variable_set(:@x, 1) },
  "singleton" => (+"sg").tap { def _1.foo = 1 },
  "chilled" => eval('"chill"'),
}
begin; require "active_support"; require "active_support/core_ext/string/output_safety"; cases["safebuf"] = "<b>".html_safe; rescue LoadError; cases.delete("safebuf"); end
def desc(o, src)
  [o.class, o.encoding, o.frozen?, o.equal?(src), o == src, o.bytes.first(4), o.instance_variables, o.singleton_methods, o.valid_encoding?,
   (o.respond_to?(:html_safe?) ? o.html_safe? : :na), (begin; o << "z"; :mutable; rescue => e; e.class; end), src.frozen?, (ObjectSpace.memsize_of(o) rescue 0)]
end
require "objspace"
cases.each do |k, v|
  ra = desc(a(v), v); rb = desc(b(v), v)
  puts "#{ra == rb ? 'SAME' : 'DIFF'} #{k}: #{ra == rb ? '' : "\n  main #{ra.inspect}\n  cand #{rb.inspect}"}"
end
