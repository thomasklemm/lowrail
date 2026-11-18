# Rails ActiveSupport::SafeBuffer through Rack::Utils.escape/unescape against URI, and how Rails uses the result.
require "active_support"; require "active_support/core_ext/string/output_safety"; require "rack/utils"
def o(r) = "#{r.inspect} #{r.class}#{r.respond_to?(:html_safe?) ? " html_safe=#{r.html_safe?}" : ""}"
["a", "a b", "<x>&y"].each do |raw|
  puts "escape #{raw.inspect}: URI #{o(URI.encode_www_form_component(raw.html_safe))} | Rack #{o(Rack::Utils.escape(raw.html_safe))}"
  puts "unescape #{raw.inspect}: URI #{o(URI.decode_www_form_component(raw.html_safe))} | Rack #{o(Rack::Utils.unescape(raw.html_safe))}"
end
# An html-unsafe buffer: a bang method such as gsub! sets @html_unsafe, which a copy without initialize_copy drops.
["a", "a b"].each do |raw|
  unsafe = -> { raw.html_safe.tap { |v| v.gsub!("a", "a") } }
  puts "escape unsafe #{raw.inspect}: URI #{o(URI.encode_www_form_component(unsafe.()))} | Rack #{o(Rack::Utils.escape(unsafe.()))}"
  puts "unescape unsafe #{raw.inspect}: URI #{o(URI.decode_www_form_component(unsafe.()))} | Rack #{o(Rack::Utils.unescape(unsafe.()))}"
end
puts "set_cookie_header: #{Rack::Utils.set_cookie_header("k", "a b".html_safe).inspect} / build_query: #{Rack::Utils.build_query("k" => "a".html_safe).inspect} #{Rack::Utils.build_query("k" => "a".html_safe).class}"
