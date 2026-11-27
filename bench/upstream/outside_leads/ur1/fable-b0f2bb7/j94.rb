# jruby -I LIB j94.rb: which decoder each method takes on this Ruby, and the result class for String subclasses.
require "uri"
sub = Class.new(String)
p engine: RUBY_ENGINE, version: (defined?(JRUBY_VERSION) ? JRUBY_VERSION : RUBY_VERSION)
p unescape_native: CGI.method(:unescape).source_location.nil?,
  uri_component_native: CGI.respond_to?(:unescapeURIComponent) && CGI.method(:unescapeURIComponent).source_location.nil?,
  b_keeps_subclass: sub.new("a").b.class != String
%w[decode_www_form_component decode_uri_component].each do |m|
  p m => ["", "a", "a+b", "a%41"].map { |s| URI.public_send(m, sub.new(s)).class == String }
end
