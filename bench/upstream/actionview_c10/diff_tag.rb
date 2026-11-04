# frozen_string_literal: true

# Differential harness for the append_tag_option candidates (T1: String values
# first; T2: Array values joined without safe_join). Prints one line per probe:
# the rendered result (or exception class and message), its class, encoding and
# html_safe?, and the calls the probe recorded on user objects. Run against base
# and candidate and diff the outputs:
#   BUNDLE_GEMFILE=VARIANT/Gemfile ruby [--yjit|--zjit] diff_tag.rb > out.txt
require "bundler/setup"
require "action_view"
require "bigdecimal"

$calls = []
def rec(*a) = $calls << a.join(":")

class LoudString < String
  def to_s = (rec(:LoudString_to_s); super)
  def html_safe? = (rec(:LoudString_html_safe?); super)
end

class SwapString < String
  def to_s = (rec(:SwapString_to_s); "<swapped>")
end

class LoudArray < Array
  def flatten(*) = (rec(:LoudArray_flatten); super)
  def map!(*) = (rec(:LoudArray_map!); super)
  def join(*) = (rec(:LoudArray_join); super)
  def each(*) = (rec(:LoudArray_each); super)
end

class LoudHash < Hash
  def flatten(*) = (rec(:LoudHash_flatten); super)
  def each_pair(*) = (rec(:LoudHash_each_pair); super)
end

class ToS
  def initialize(s) = @s = s
  def to_s = (rec(:ToS_to_s, @s); @s)
end

class SafeToS
  def to_s = (rec(:SafeToS_to_s); "<b>".html_safe)
end

class Boom
  def to_s = raise(ArgumentError, "boom to_s")
end

class EqqLike
  def to_s = (rec(:EqqLike_to_s); "eqq")
end

def singleton_to_s
  s = +"<orig>"
  s.define_singleton_method(:to_s) { rec(:singleton_to_s); "<single>" }
  s
end

def singleton_html_safe
  s = +"<orig>"
  s.define_singleton_method(:html_safe?) { rec(:singleton_html_safe?); true }
  s
end

def unsafe_buffer
  b = ActiveSupport::SafeBuffer.new("a<b")
  b.gsub!("a", "&") # marks it unsafe
  b
end

def extended_string
  s = +"ext"
  s.extend(Module.new { def to_s = (rec(:extended_to_s); "<ext>") })
  s
end

VALUES = {
  "plain" => -> { "card" },
  "quote" => -> { %(say "hi") },
  "lt_amp" => -> { "<a & b>" },
  "frozen" => -> { "frozen<".freeze },
  "empty" => -> { +"" },
  "utf8" => -> { "caf\u00e9 \u2028" },
  "binary" => -> { "bin\xff".b },
  "sjis" => -> { "\x82\xa0".dup.force_encoding("Shift_JIS") },
  "utf16" => -> { "u16".encode("UTF-16LE") },
  "invalid_utf8" => -> { "bad\xff<" },
  "safe_buffer" => -> { "<i>safe</i>".html_safe },
  "safe_buffer_quote" => -> { %(<i title="x">).html_safe },
  "unsafe_buffer" => -> { unsafe_buffer },
  "loud_string" => -> { LoudString.new("<loud>") },
  "swap_string" => -> { SwapString.new("<orig>") },
  "singleton_to_s" => -> { singleton_to_s },
  "singleton_html_safe" => -> { singleton_html_safe },
  "extended" => -> { extended_string },
  "symbol" => -> { :"sym<bol>" },
  "integer" => -> { 42 },
  "float" => -> { 1.5 },
  "bigdecimal" => -> { BigDecimal("1.25") },
  "true" => -> { true },
  "false" => -> { false },
  "regexp" => -> { /a<b"/ },
  "to_s_object" => -> { ToS.new(%(<o "x">)) },
  "safe_to_s" => -> { SafeToS.new },
  "boom" => -> { Boom.new },
  "array" => -> { ["a", "<b>", nil, :c] },
  "nested_array" => -> { ["a", ["b", ["<c>"]], "d"] },
  "array_safe" => -> { ["<x>".html_safe, "<y>"] },
  "array_quote" => -> { [%(a"b), %(<i class="z">).html_safe] },
  "array_objects" => -> { [ToS.new("t<1"), 7, SafeToS.new] },
  "array_boom" => -> { ["a", Boom.new] },
  "array_empty" => -> { [] },
  "loud_array" => -> { LoudArray["x", "<y>"] },
  "array_frozen" => -> { ["f", "<g>"].freeze },
  "hash" => -> { { "a" => true, "<b>" => false, c: 1 } },
  "loud_hash" => -> { LoudHash["k" => "v", "<k2>" => 2] },
  "eqq_like" => -> { EqqLike.new },
}.freeze

KEYS = [:class, "class", :id, :title, :rel, "data-x", :"my-attr"].freeze

view = ActionView::Base.empty
probes = []
VALUES.each do |vname, vf|
  KEYS.each do |key|
    [true, false].each do |escape|
      probes << ["tag.div #{key.inspect} #{vname} escape=#{escape}", -> { view.tag.div("x", key => vf.(), escape: escape) }]
      probes << ["tag.input #{key.inspect} #{vname} escape=#{escape}", -> { view.tag.input(key => vf.(), escape: escape) }]
    end
  end
  probes << ["content_tag a #{vname}", -> { view.content_tag(:a, "y", href: vf.(), title: vf.()) }]
  probes << ["content_tag noescape #{vname}", -> { view.content_tag(:a, "y", { href: vf.() }, false) }]
  probes << ["tag() #{vname}", -> { view.tag(:img, src: vf.(), alt: vf.()) }]
  probes << ["data #{vname}", -> { view.tag.div(data: { v: vf.() }) }]
  probes << ["aria #{vname}", -> { view.tag.div(aria: { v: vf.() }) }]
  probes << ["attributes #{vname}", -> { view.tag.attributes(title: vf.(), class: vf.()) }]
  probes << ["hidden #{vname}", -> { view.tag.div(hidden: vf.()) }]
end
probes << ["link_to", -> { view.link_to("a<b", "/x?a=1&b=2", class: ["btn", "btn-<x>"], data: { turbo: false }) }]
probes << ["text_field_tag", -> { view.text_field_tag("q", %(v"<), class: "c", placeholder: :ph) }]
probes << ["mutation during each", -> { h = { title: "a" }; v = ToS.new("x"); v.define_singleton_method(:to_s) { h[:late] = 1 rescue rec($!.class); "x" }; h[:id] = v; view.content_tag(:div, "c", h) }]

probes << ["array with unsafe buffer", -> { view.tag.div(class: [unsafe_buffer, "z"]) }]
probes << ["data array", -> { view.tag.div("x", rel: ["a", ["<b>"]], "data-list": ["1", 2]) }]
custom = ActionView::Base.empty
custom.define_singleton_method(:safe_join) { |a, s = nil| rec(:custom_safe_join); super(a, s) }
probes << ["view with its own safe_join", -> { custom.tag.div("x", class: ["a", "b"]) }]
probes << ["view with its own safe_join, token_list", -> { custom.tag.div("x", class: custom.token_list("a", "b")) }]

repeat = Integer(ENV.fetch("REPEAT", "1"))
repeat.times do |i|
  probes.each do |name, f|
    $calls = []
    out = begin
      r = f.()
      "#{r.inspect} #{r.class} #{r.encoding} #{r.html_safe?} frozen=#{r.frozen?}"
    rescue Exception => e # rubocop:disable Lint/RescueException
      "raised #{e.class}: #{e.message[0, 200]}"
    end
    puts "#{name} => #{out.gsub(/0x\h+/, "0x")} calls=#{$calls.join(",")}" if i == repeat - 1
  end
end
