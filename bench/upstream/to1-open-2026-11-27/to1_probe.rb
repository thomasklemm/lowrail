# frozen_string_literal: true
# Differential probe for TO1: every tag helper that reaches tag() or a void tag.* element, over attribute order,
# escaping, data/aria Hashes, booleans, nil values, odd keys and values, encodings, SafeBuffer state of the result,
# and calls on user objects. One line per case; diff main against the head.
#   bundle exec ruby to1_probe.rb <rails checkout>
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_model"
require "action_view"
require "action_controller"
require "bigdecimal"

V = ActionView::Base.with_empty_template_cache.with_view_paths([])
V.define_singleton_method(:protect_against_forgery?) { false }
LOG = []
class Probe
  def initialize(s) = @s = s
  def to_s = (LOG << "to_s(#{@s})"; @s)
  def to_json(*) = (LOG << "to_json(#{@s})"; @s.to_json)
  def inspect = "Probe(#{@s})"
end
class BadToS
  def to_s = raise(ArgumentError, "boom")
end
class SubStr < String
  def to_s = "sub!"
end
class SubHash < Hash
  def each_pair(&) = (LOG << "SubHash#each_pair"; super)
end

def describe(r)
  return r.inspect unless r.is_a?(String)
  "#{r.class} frozen=#{r.frozen?} safe=#{r.html_safe?} enc=#{r.encoding} #{r.to_str.inspect}"
end
def show(label)
  LOG.clear
  out = begin
    describe(yield)
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#{e.class}: #{e.message[0, 160].gsub(/0x\h+/, "0x")}"
  end
  puts "#{label}\t#{out}\t#{LOG.join(",")}"
end

values = [nil, false, true, "", " ", "v", "a\"b<c>&d'", "<b>".html_safe, :sym, 0, 1.5, BigDecimal("1.10"), [], ["a", "b"],
          ["a", nil, :b], { a: 1 }, Set[1, 2], /re"x/, Probe.new("p"), SubStr.new("s"), "été", "\xFF".b, "x".b,
          "\xFF".dup.force_encoding("UTF-8"), "x".encode("UTF-16LE"), "until-found", Object, BadToS.new]
keys = [:id, "id", :class, :data, :aria, :disabled, :hidden, :checked, :"data-x", :"aria-x", "x y", "", " ", nil,
        :"a\"b", :"<k>", "été", Probe.new("k"), 1]
names = [:input, "input", :img, "br", :meta, :link, "my-element", Probe.new("input"), "été", :"in\"put"]

option_sets = []
keys.each { |k| values.each { |v| option_sets << { k => v } } }
option_sets += [
  { id: "a", class: "b", "id" => "c" }, { b: 1, a: 2, c: 3 }, { "c" => 1, :b => 2, "a" => 3 },
  { data: { controller: "x", turbo_frame: "f", n: nil, "" => 1, nil => 2, h: { a: 1 }, arr: [1, 2], big: BigDecimal("2"),
            sym: :s, t: true, f: false, p: Probe.new("dp") } },
  { aria: { label: "L", describedby: ["a", nil, "b"], expanded: false, empty: [], h: { a: true, b: false }, nil: nil,
            p: Probe.new("ap") } },
  { class: ["a", { b: true, c: false }, nil, "<x>", ["d", ["e"]]] }, { class: Set["x", "y"] }, { class: { on: true } },
  { disabled: true, readonly: false, required: "required", multiple: nil, hidden: :"until-found", "hidden" => "x" },
  { data: "plain", aria: "plain", "data" => { a: 1 } }, { data: SubHash[:a, 1] }, SubHash[:x, 1, :y, 2],
  ActiveSupport::HashWithIndifferentAccess.new("class" => "c", data: { a: 1 }), { data: {}, aria: {} },
  { nil => 1, "" => 2 }, { id: nil }, { escape: false, a: "<" }, { value: "x" * 300, name: "y" * 300, data: { z: "w" * 300 } },
  { a: "\xFF".b, b: "été" }, { a: "été", b: "\xFF".b }, { a: "x".encode("UTF-16LE") }, { "été" => "\xFF".b },
  { a: BadToS.new, b: Probe.new("never") }, { a: Probe.new("first"), b: BadToS.new },
]
option_sets << { a: 1 }.freeze
option_sets << { a: "x".freeze }
frozen_name_opts = { a: 1 }.tap { |h| h.compare_by_identity }
option_sets << frozen_name_opts

names.each_with_index do |n, ni|
  show("tag name #{ni}") { V.tag(n) }
  show("tag name nil #{ni}") { V.tag(n, nil) }
  show("tag name {} #{ni}") { V.tag(n, {}) }
  show("tag name open #{ni}") { V.tag(n, { a: 1 }, true) }
end
[nil, false, "", [], "str", 1, [[:a, 1]], { a: 1 }.to_a].each_with_index do |o, i|
  show("tag opts #{i}") { V.tag(:br, o) }
  show("tag opts open #{i}") { V.tag(:br, o, true, false) }
end
option_sets.each_with_index do |o, i|
  [true, false].each do |esc|
    show("tag #{i} #{esc}") { V.tag(:input, o.dup, false, esc) }
    show("tag open #{i} #{esc}") { V.tag(:div, o.dup, true, esc) }
    kw = o.to_h.select { |k, _| Symbol === k }
    show("tag.input #{i} #{esc}") { V.tag.input(escape: esc, **kw) }
    show("tag.br #{i} #{esc}") { V.tag.br(escape: esc, **kw) }
    show("tag.img #{i} #{esc}") { V.tag.img(escape: esc, **kw) }
    show("tag.svg-self #{i} #{esc}") { V.tag.path(escape: esc, **kw) }
    show("attributes #{i}") { V.tag.attributes(o) } if esc
    show("content_tag #{i} #{esc}") { V.content_tag(:p, "c", o.dup, esc) }
  end
  show("text_field_tag #{i}") { V.text_field_tag("n", "v", o.dup) }
  show("hidden_field_tag #{i}") { V.hidden_field_tag("n", "v", o.dup) }
  show("password_field_tag #{i}") { V.password_field_tag("n", "v", o.dup) }
  show("check_box_tag #{i}") { V.check_box_tag("n", "1", true, o.dup) }
  show("radio_button_tag #{i}") { V.radio_button_tag("n", "1", true, o.dup) }
  show("submit_tag #{i}") { V.submit_tag("Save", o.dup) }
  show("image_submit_tag #{i}") { V.image_submit_tag("/a.png", o.dup) }
  show("image_tag #{i}") { V.image_tag("/a.png", o.dup) }
  show("file_field_tag #{i}") { V.file_field_tag("f", o.dup) }
end
show("csrf_meta_tags") { V.csrf_meta_tags }
show("form_tag") { V.form_tag("/x", class: "f") }
show("form_tag get") { V.form_tag("/x", method: :get, data: { a: 1 }) }
show("button_to") { V.button_to("x", "/p", params: { a: 1, b: [1, "<"] }, data: { turbo: false }) }
show("favicon_link_tag") { V.favicon_link_tag("/f.ico") }
show("auto_discovery_link_tag") { V.auto_discovery_link_tag(:rss, "/feed") }
show("stylesheet_link_tag") { V.stylesheet_link_tag("/a.css", media: "all") }
show("preload_link_tag") { V.preload_link_tag("/a.css") }
show("video_tag") { V.video_tag(["/a.mp4", "/b.webm"]) }
show("picture_tag") { V.picture_tag("/a.webp", "/a.png") }
show("select_hour") { V.select_hour(Time.utc(2026, 1, 1, 13), ignore_date: true) }
show("time_select hidden") { V.select_time(Time.utc(2026, 1, 1, 13), include_seconds: false) }
show("csp_meta_tag") { V.csp_meta_tag }

# Frozen-ness and identity: the result is fresh each call, not shared.
a = V.tag(:br, a: 1); b = V.tag(:br, a: 1)
puts "fresh\t#{a.equal?(b)} #{a.to_str.equal?(b.to_str)}"
s = V.tag.input(type: "text")
puts "mutate\t#{begin; s << "x"; s.to_str.inspect; rescue => e; e.class; end}"
