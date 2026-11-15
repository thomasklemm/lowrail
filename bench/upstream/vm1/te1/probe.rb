# frozen_string_literal: true

# Differential probe for TE1: tag attribute values and content_tag content through every
# escape branch, with the calls each value receives. Run once per Rails tree and diff:
#   ruby probe.rb RAILS_DIR > out.txt
tree = ARGV.fetch(0)
%w[activesupport actionview activemodel actionpack].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "action_view"
require "bigdecimal"

view = ActionView::Base.empty
calls = []

counted = lambda do |obj, label|
  return obj if obj.is_a?(Symbol) || obj.is_a?(Numeric) || obj == true || obj == false || obj.is_a?(Regexp)

  obj.singleton_class.prepend(Module.new do
    define_method(:to_s) { calls << "#{label}.to_s"; super() }
    define_method(:html_safe?) { calls << "#{label}.html_safe?"; super() }
  end)
  obj
end

class Unsafe
  def initialize(str) = @str = str
  def to_s = @str
end

class OddString < String
  def to_s = OddString.new("odd<#{self}>")
end

class SafeTo
  def to_s = "<i>safe</i>".html_safe
end

class RaisesToS
  def to_s = raise(ArgumentError, "no to_s")
end

class NilToS
  def to_s = nil
end

class FakeSafe < String
  def html_safe? = true
end

values = {
  "plain" => -> { +"author-link" },
  "specials" => -> { +%(a<b>&"c'd) },
  "frozen specials" => -> { %(x<y>).freeze },
  "empty" => -> { +"" },
  "safe buffer" => -> { "<b>bold</b>".html_safe },
  "safe buffer quote" => -> { '"'.html_safe },
  "fake safe subclass" => -> { FakeSafe.new("<u>") },
  "odd string subclass" => -> { OddString.new("s") },
  "binary" => -> { "a<b\xFF".b },
  "invalid utf-8" => -> { +"a<b\xFF" },
  "utf-16" => -> { "a<b".encode("UTF-16LE") },
  "symbol" => -> { :"sym<&>" },
  "plain symbol" => -> { :post },
  "regexp" => -> { /\A<[a-z]+>&\z/ },
  "integer" => -> { 42 },
  "float" => -> { 1.5 },
  "bigdecimal" => -> { BigDecimal("1.25") },
  "true" => -> { true },
  "false" => -> { false },
  "object" => -> { Unsafe.new("<script>") },
  "object safe to_s" => -> { SafeTo.new },
  "object nil to_s" => -> { NilToS.new },
  "object raising to_s" => -> { RaisesToS.new },
  "array" => -> { ["a<b", "c".html_safe, :d] },
  "hash" => -> { { "a<b" => true, c: false } },
  "time" => -> { Time.utc(2026, 11, 15, 1, 2, 3) },
}

describe = lambda do |result|
  "#{result.inspect} #{result.class} #{result.encoding} safe=#{result.html_safe?} frozen=#{result.frozen?}"
end

run = lambda do |label, &blk|
  calls.clear
  result = begin
    describe.(blk.call)
  rescue Exception => e
    "raised #{e.class}: #{e.message}"
  end
  puts "#{label}: #{result} calls=#{calls.join(",")}"
end

values.each do |name, make|
  [true, false].each do |escape|
    run.("tag.a title #{name} escape=#{escape}") { view.tag.a("x", title: counted.(make.(), "v"), escape: escape) }
    run.("tag.a data #{name} escape=#{escape}") { view.tag.a("x", data: { info: counted.(make.(), "v") }, escape: escape) }
    run.("tag.a class #{name} escape=#{escape}") { view.tag.a("x", class: counted.(make.(), "v"), escape: escape) }
    run.("content_tag #{name} escape=#{escape}") { view.content_tag(:p, counted.(make.(), "c"), { id: "p" }, escape) }
    run.("tag() #{name} escape=#{escape}") { view.tag("input", { value: counted.(make.(), "v") }, false, escape) }
  end
  run.("tag.attributes #{name}") { view.tag.attributes(value: counted.(make.(), "v")) }
  run.("tag.p content #{name}") { view.tag.p(counted.(make.(), "c")) }
  run.("content_tag block #{name}") { view.content_tag(:div, class: counted.(make.(), "v")) { "inner<" } }
end

run.("tag.escape_html") { view.tag.escape_html("x") }
run.("tag respond_to escape_html") { view.tag.respond_to?(:escape_html) }
run.("tag.escape_html attr") { view.tag.escape_html(title: "<") }

ERB::Util.singleton_class.prepend(Module.new do
  def unwrapped_html_escape(s)
    "[util]#{super}"
  end
end)
run.("prepended ERB::Util.unwrapped_html_escape title") { view.tag.a("x", title: +"<") }
run.("prepended ERB::Util.unwrapped_html_escape content") { view.content_tag(:p, +"<") }
run.("prepended ERB::Util.unwrapped_html_escape safe_join") { view.safe_join([+"<"]) }
