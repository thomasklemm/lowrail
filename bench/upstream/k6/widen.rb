# frozen_string_literal: true

# widen.rb: K6's own differential probe, beside census 9's button_to_diff.rb.
# Prints button_to's output (class, html_safe?, encoding, frozen?, and the
# String) or the exception for param inputs and call contexts that grid does
# not reach, for a Rails checkout in RAILS. Run on two trees and diff.
#
# Groups: odd keys (Symbol, Integer, nil, true/false, Float, objects with their
# own to_s, html_safe and escaping-needing Strings, String subclasses, encodings),
# odd values (nil, false, true, Symbol, numbers, dates, to_param returning nil,
# Arrays, Hashes, html_safe Strings, raising), nested Hash/Array shapes,
# ActionController::Parameters and HashWithIndifferentAccess, the button's own
# options, calls inside capture and content_tag, an ERB template, and
# overrides of form_tag, tag, hidden_field_tag, text_field_tag and
# sanitize_to_id in a view subclass. The last three are expected to differ:
# main routes params through them, K6 (like 8.1) does not.
rails = ENV.fetch("RAILS")
%w[activesupport actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "action_view"
require "action_controller"
require "bigdecimal"

ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw { resources(:posts) }
class View < ActionView::Base
  include ROUTES.url_helpers
  def default_url_options = { only_path: true }
end
class CsrfView < View
  def protect_against_forgery? = true
  def form_authenticity_token(form_options: {}) = "tok-#{form_options[:method]}-#{form_options[:action]}"
  def request_forgery_protection_token = :authenticity_token
end

ToS = Struct.new(:s) { def to_s = s }
class ParamObj
  def initialize(v) = @v = v
  def to_param = @v
  def inspect = "#<ParamObj #{@v.inspect}>"
end
class Raising
  def to_param = raise(ArgumentError, "no param")
  def to_s = raise(ArgumentError, "no to_s")
  def inspect = "#<Raising>"
end
class SubString < String
  def to_s = "sub(#{super})"
end
class LoudHash < Hash; end

keys = [
  :sym, "str", 1, 1.5, nil, true, false, :"a b", "a\"b", "a'b", "<k>&", "a]b", "a[b", "x[]", "]", "",
  " lead", "trail ", "tab\tnl\n", "ünï", "\u00a0", "a&amp;", "<b>".html_safe, ToS.new("t<o>s"), SubString.new("subk"),
  "bin\xff".b, "utf8\xff".dup.force_encoding("UTF-8"), "x" * 300,
]
values = [
  nil, false, true, "", "v", :sym, 1, -1.5, BigDecimal("1.10"), Date.new(2026, 11, 14), Time.utc(2026, 11, 14, 1, 2, 3),
  "<script>&\"'", "<i>ok</i>".html_safe, "a\"b", "nl\nv", ParamObj.new(nil), ParamObj.new(false), ParamObj.new(["a", "b"]),
  ParamObj.new({ "k" => "v" }), ParamObj.new("<x>".html_safe), ParamObj.new(:s), ParamObj.new(7), "bin\xff".b,
  "utf8\xff".dup.force_encoding("UTF-8"), [], {}, [nil], [false, true], [[1, [2]], { a: [3] }], { nil => 1 }, Raising.new,
]
shapes = []
keys.each { |k| shapes << { k => "v" } << { "outer" => { k => "v" } } << { "arr" => [{ k => 1 }] } }
values.each { |v| shapes << { "k" => v } << { "o" => { "i" => v } } << { "a" => [v, v] } }
shapes += [
  { a: { b: { c: { d: [1, { e: [nil, false, "x"] }] } } } },
  { "b" => 2, "a" => 1, "a[x]" => 3, "A" => 0, "_" => 9 },
  { "dup" => 1, dup: 2 },
  { [1, 2] => "arraykey" },
  { { h: 1 } => "hashkey" },
  ActiveSupport::HashWithIndifferentAccess.new("a" => 1, "b" => { "c" => 2 }),
  ActionController::Parameters.new(a: 1, b: { c: [2, 3] }).permit!,
  ActionController::Parameters.new(a: 1),
  LoudHash[{ "x" => 1 }],
  { "k" => Raising.new },
  { Raising.new => 1 },
  ["top", "level"],
  "string params",
  1,
]

out = []
dump = lambda do |label, &blk|
  result = begin
    r = blk.call
    "#{r.class} html_safe=#{r.respond_to?(:html_safe?) && r.html_safe?} enc=#{r.encoding rescue "-"} frozen=#{r.frozen?}\n  #{r.inspect}"
  rescue Exception => e
    "#{e.class}: #{e.message}"
  end
  out << "#{label}\n  #{result}"
end

[View, CsrfView].each do |klass|
  view = klass.empty
  view.output_buffer = ActionView::OutputBuffer.new
  [false, true].each do |tag_flag|
    ActionView::Helpers::NavigationHelper.button_to_generates_button_tag = tag_flag
    [false, true].each do |no_autocomplete|
      ActionView::Base.remove_hidden_field_autocomplete = no_autocomplete
      shapes.each_with_index do |params, i|
        dump.("#{klass} tag=#{tag_flag} noac=#{no_autocomplete} shape=#{i} #{params.inspect rescue "?"}") do
          view.button_to("Go", "/posts", params: params)
        end
      end
    end
  end
end
ActionView::Helpers::NavigationHelper.button_to_generates_button_tag = true
ActionView::Base.remove_hidden_field_autocomplete = false

view = CsrfView.empty
view.output_buffer = ActionView::OutputBuffer.new
P = { "a" => "<1>", "b" => [1, 2] }.freeze
dump.("button options mixed with params") { view.button_to("Go", "/p", params: P, method: :delete, form: { id: "f", data: { x: 1 } }, form_class: "c", class: "b", data: { confirm: "?" }, remote: true, disabled: true, id: "btn", name: "commit", value: "v") }
dump.("params given as string key") { view.button_to("Go", "/p", "params" => P) }
dump.("params with block") { view.button_to("/p", params: P) { "<b>Go</b>".html_safe } }
dump.("params with false url") { view.button_to("Go", false, params: P) }
dump.("params with hash url") { view.button_to("Go", { controller: "posts", action: "show", id: 1 }, params: P) }
dump.("params frozen html_options") { view.button_to("Go", "/p", { params: P, method: :patch }.freeze) }
dump.("inside capture") { view.capture { view.concat("pre"); view.concat(view.button_to("Go", "/p", params: P)); "post" } }
dump.("inside content_tag block") { view.content_tag(:div) { view.button_to("Go", "/p", params: P) } }
dump.("block button inside capture") { view.capture { view.button_to("/p", params: P) { view.concat("in"); "out" } } }
nobuf = CsrfView.empty
dump.("no output buffer") { nobuf.button_to("Go", "/p", params: P) }
dump.("ERB template") do
  ActionView::Template.new("<%= button_to 'Go', '/p', params: { 'a' => '<1>', 'b' => [1, nil] } %>|<%= button_to('/q', params: { x: 1 }) do %>B<% end %>",
    "inline", ActionView::Template::Handlers::ERB.new, locals: [], format: :html).render(CsrfView.empty, {})
end

overrides = {
  form_tag: Module.new { def form_tag(*a, **k, &b) = "[form_tag]".html_safe + super },
  tag: Module.new { def tag(name = nil, options = nil, *rest) = (name.to_s == "input" ? "[tag]".html_safe : "".html_safe) + super },
  hidden_field_tag: Module.new { def hidden_field_tag(*a) = "[hidden_field_tag]".html_safe + super },
  text_field_tag: Module.new { def text_field_tag(*a) = "[text_field_tag]".html_safe + super },
  sanitize_to_id: Module.new { def sanitize_to_id(name) = "[sanitize_to_id]#{super}" },
}
overrides.each do |name, mod|
  klass = Class.new(CsrfView) { prepend mod }
  v = klass.empty
  v.output_buffer = ActionView::OutputBuffer.new
  dump.("override #{name}") { v.button_to("Go", "/p", params: { "a" => 1 }) }
end

puts out
warn "#{out.size} cases (button_to at #{ActionView::Helpers::NavigationHelper.instance_method(:button_to).source_location.join(":")})"
