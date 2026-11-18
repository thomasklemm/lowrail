# How Rack treats String subclasses and BasicObject in escape/unescape and neighbouring methods.
require "rack/utils"
Sub = Class.new(String)
b = BasicObject.new; def b.to_s; "a b"; end
bs = BasicObject.new; def bs.to_str; "a%41"; end; def bs.b; "a%41".b; end
def t(label)
  r = yield
  puts "#{label}: #{r.inspect} (#{::Kernel.instance_method(:class).bind_call(r)})"
rescue Exception => e
  puts "#{label}: raises #{e.class}: #{e.message[0, 90]}"
end
puts "#{RUBY_VERSION} cgi/util=#{$LOADED_FEATURES.any? { _1.end_with?("cgi/util.rb") }}"
t("escape_html(Sub 'a')") { Rack::Utils.escape_html(Sub.new("a")) }
t("escape_html(Sub '<')") { Rack::Utils.escape_html(Sub.new("<")) }
t("escape_html(BasicObject to_s)") { Rack::Utils.escape_html(b) }
t("escape_path(BasicObject to_s)") { Rack::Utils.escape_path(b) }
t("escape_path(Sub 'a')") { Rack::Utils.escape_path(Sub.new("a")) }
t("unescape_path(Sub 'a')") { Rack::Utils.unescape_path(Sub.new("a")) }
t("unescape_path(BasicObject to_str)") { Rack::Utils.unescape_path(bs) }
t("build_query(x: BasicObject)") { Rack::Utils.build_query("x" => b) }
t("build_nested_query(x: BasicObject)") { Rack::Utils.build_nested_query("x" => b) }
t("set_cookie_header(BasicObject)") { Rack::Utils.set_cookie_header("k", b) }
t("build_query(x: Sub 'a')") { Rack::Utils.build_query("x" => Sub.new("a")) }
t("parse_query(Sub 'a=b') value") { Rack::Utils.parse_query(Sub.new("a=b")).values.first }
t("parse_query(BasicObject)") { Rack::Utils.parse_query(bs) }
t("parse_nested_query(BasicObject)") { Rack::Utils.parse_nested_query(bs) }
t("parse_cookies_header(BasicObject)") { Rack::Utils.parse_cookies_header(bs) }
t("parse_cookies_header('a')") { Rack::Utils.parse_cookies_header("a") }
t("escape(BasicObject to_s)") { Rack::Utils.escape(b) }
t("unescape(BasicObject to_str+b)") { Rack::Utils.unescape(bs) }
t("escape(Sub 'a')") { Rack::Utils.escape(Sub.new("a")) }
t("escape(Sub 'a b')") { Rack::Utils.escape(Sub.new("a b")) }
t("unescape(Sub 'a')") { Rack::Utils.unescape(Sub.new("a")) }
t("unescape(Sub 'a%41')") { Rack::Utils.unescape(Sub.new("a%41")) }
t("escape(nil)") { Rack::Utils.escape(nil) }
t("unescape(nil)") { Rack::Utils.unescape(nil) }
t("escape(:sym)") { Rack::Utils.escape(:"a b") }
t("escape(1)") { Rack::Utils.escape(1) }
t("unescape(:sym)") { Rack::Utils.unescape(:"a%41") }
