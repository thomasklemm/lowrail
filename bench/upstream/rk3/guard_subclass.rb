# Which fields differ from URI for String subclasses, and only for them, under a given Rack lib.
#   ruby -I RACK/lib subclass_probe.rb
require "rack/utils"
def out(&b) = (r = b.call; {class: r.class.name || "subclass", enc: r.encoding.name, bytes: String.instance_method(:b).bind_call(r), frozen: r.frozen?, valid: r.valid_encoding?}) rescue {err: $!.class, msg: $!.message[0, 60]}
plain = Class.new(String)
safe = Class.new(String) { def to_s = self; def html_safe? = true } # ActiveSupport::SafeBuffer#to_s returns self
hooks = { # subclasses whose methods URI calls, with different answers
  "to_s" => Class.new(String) { def to_s = "hooked" }, "b" => Class.new(String) { def b = "hooked".b },
  "dup" => Class.new(String) { def dup = "hooked" }, "gsub" => Class.new(String) { def gsub(*) = "hooked" },
}
qp = Rack::Utils.default_query_parser
inputs = ["", "a", "a b", "a%41", "%E3%81%82", "*~", "a%", "\xFF".b, "é"]
diffs = Hash.new { |h, k| h[k] = [] }
{"plain" => plain, "SafeBuffer-like" => safe, **hooks.transform_keys { "overrides #{_1}" }}.each do |name, k|
  inputs.each do |raw|
    [[:escape, -> s { URI.encode_www_form_component(s) }, -> s { Rack::Utils.escape(s) }],
     [:unescape, -> s { URI.decode_www_form_component(s) }, -> s { Rack::Utils.unescape(s) }],
     [:query_unescape, -> s { URI.decode_www_form_component(s) }, -> s { qp.send(:unescape, s) }]].each do |m, u, r|
      a = out { u.(k.new(raw)) }; b = out { r.(k.new(raw)) }
      next if a == b
      fields = a.keys.select { a[_1] != b[_1] }
      diffs["#{name} #{m}"] << "#{raw.inspect}: #{fields.map { |f| "#{f} #{a[f].inspect}->#{b[f].inspect}" }.join(", ")}"
    end
  end
end
puts "#{RUBY_VERSION} cgi=#{CGI.method(:escape).source_location ? "ruby" : "C"} util=#{$LOADED_FEATURES.any? { _1.end_with?("cgi/util.rb") }}"
diffs.each { |k, v| puts "#{k}: #{v.join("; ")}" }
puts "no differences" if diffs.empty?
