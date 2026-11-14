# frozen_string_literal: true

# review_probe.rb: claude-code review of K6. Inputs beyond button_to_diff.rb and
# widen.rb; prints button_to's result or exception per case for RAILS. Run on two trees and diff.
rails = ENV.fetch("RAILS")
%w[activesupport actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "action_view"
require "action_controller"

class View < ActionView::Base
  def protect_against_forgery? = false
end

out = []
dump = lambda do |label, view = View.empty, &blk|
  view.output_buffer ||= ActionView::OutputBuffer.new
  r = begin
    x = blk.call(view)
    "#{x.class} safe=#{x.html_safe?} enc=#{x.encoding} #{x.inspect}"
  rescue Exception => e
    "#{e.class}: #{e.message}"
  end
  out << "#{label}\n  #{r}"
end

encs = {
  "utf16le" => "k".encode("UTF-16LE"),
  "utf16le_nonascii" => "é".encode("UTF-16LE"),
  "utf32be" => "k".encode("UTF-32BE"),
  "sjis" => "日本".encode("Shift_JIS"),
  "sjis_bad" => "\x81".dup.force_encoding("Shift_JIS"),
  "latin1" => "é]".encode("ISO-8859-1"),
  "eucjp" => "日".encode("EUC-JP"),
  "usascii_high" => "a\xff".dup.force_encoding("US-ASCII"),
  "win1252" => "\x80".dup.force_encoding("Windows-1252"),
  "iso2022jp_dummy" => "a".dup.force_encoding("ISO-2022-JP"),
  "utf7_dummy" => "a".dup.force_encoding("UTF-7"),
  "utf8_bad_bracket" => "a]\xff[b".dup.force_encoding("UTF-8"),
  "utf8_overlong" => "\xc0\xaf".dup.force_encoding("UTF-8"),
  "utf8_surrogate" => "\xed\xa0\x80".dup.force_encoding("UTF-8"),
  "bin_bracket" => "]\xff".b,
}
encs.each do |label, s|
  dump.("key #{label}") { |v| v.button_to("Go", "/p", params: { s => "v" }) }
  dump.("value #{label}") { |v| v.button_to("Go", "/p", params: { "k" => s }) }
  dump.("key #{label} after utf8 key") { |v| v.button_to("Go", "/p", params: { "a" => "é", s => "v" }) }
  dump.("key #{label} noac") do |v|
    ActionView::Base.remove_hidden_field_autocomplete = true
    v.button_to("Go", "/p", params: { s => 1 })
  ensure
    ActionView::Base.remove_hidden_field_autocomplete = false
  end
end

# A key whose to_s returns a String subclass with a non-idempotent to_s:
# main calls name.to_s twice (sanitize_to_id, then escaping), K6 once.
class Counting < String
  def to_s = "#{self}#{@n = (@n || 0) + 1}"
end
class KeyObj
  def initialize(s) = @s = s
  def to_s = Counting.new(@s)
end
dump.("key to_s counting") { |v| v.button_to("Go", "/p", params: { KeyObj.new("k") => "v" }) }

# tag overrides that read the attribute Hash: main passes "type" => :hidden
# with String keys from text_field_tag, K6 passes type: "hidden" with Symbols.
reader = Module.new do
  def tag(name = nil, options = nil, *rest)
    if name.to_s == "input" && options
      mark = options.keys.map { |k| "#{k.class}:#{k}=#{options[k].class}" }.join(",")
      return "[#{mark}]".html_safe + super
    end
    super
  end
end
dump.("tag override reading keys", Class.new(View) { prepend reader }.empty) { |v| v.button_to("Go", "/p", params: { a: 1 }) }

nonce = Module.new do
  def tag(name = nil, options = nil, *rest)
    options = options.merge("data-hidden" => "1") if name.to_s == "input" && options && options["type"].to_s == "hidden"
    super(name, options, *rest)
  end
end
dump.("tag override keyed by 'type'", Class.new(View) { prepend nonce }.empty) { |v| v.button_to("Go", "/p", params: { a: 1 }) }

# Settings: truthy non-boolean values.
["false", 0, nil, :off].each do |val|
  dump.("remove_hidden_field_autocomplete=#{val.inspect}") do |v|
    ActionView::Base.remove_hidden_field_autocomplete = val
    v.button_to("Go", "/p", params: { a: 1 })
  ensure
    ActionView::Base.remove_hidden_field_autocomplete = false
  end
end

# Names that sanitize_to_id would rewrite heavily; values that are boolean-ish.
dump.("names with id-unsafe chars") { |v| v.button_to("Go", "/p", params: { "a b" => 1, "c.d:e-f" => 2, "x[y][]" => [3], "\u0000" => 4 }) }
dump.("value Regexp") { |v| v.button_to("Go", "/p", params: { a: /re"g/ }) }
dump.("value object to_param Regexp") { |v| v.button_to("Go", "/p", params: { a: Struct.new(:x) { def to_param = /r/ }.new(1) }) }
dump.("value to_param hash with data key") { |v| v.button_to("Go", "/p", params: { data: Struct.new(:x) { def to_param = { "x" => 1 } }.new(1) }) }
dump.("key 'hidden' boolean-attr name") { |v| v.button_to("Go", "/p", params: { "hidden" => "until-found", "class" => %w[a b], "aria" => "x" }) }
dump.("params as AC::Parameters unpermitted nested") { |v| v.button_to("Go", "/p", params: ActionController::Parameters.new(a: { b: 1 }).permit(a: [:b])) }
dump.("button_to in FormTagHelper-only class") do
  k = Class.new { include ActionView::Helpers::NavigationHelper; include ActionView::Helpers::FormTagHelper; attr_accessor :output_buffer; def url_for(x) = x.to_s }
  k.new.tap { _1.output_buffer = ActionView::OutputBuffer.new }.button_to("Go", "/p", params: { a: 1 })
end

# Global overrides on the helper modules (an app or gem prepending into Rails).
dump.("FormTagHelper.prepend hidden_field_tag (global)") do |v|
  ActionView::Helpers::FormTagHelper.prepend(Module.new { def hidden_field_tag(n, val = nil, o = {}) = super(n, val, o.merge(data: { g: 1 })) })
  View.empty.tap { _1.output_buffer = ActionView::OutputBuffer.new }.button_to("Go", "/p", params: { a: 1 })
end

puts out
warn "#{out.size} cases"
