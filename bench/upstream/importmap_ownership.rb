# frozen_string_literal: true

# Public-helper ownership probes, run independently against before/after source.
require "json"
require "active_support/all"
require "action_view"
module Importmap; end
load ARGV.fetch(0)

class RetainedArray < Array
  attr_reader :collected, :operation

  def collect(&block)
    @operation = block
    @collected = super
  end
end

class RetainedHash < Hash
  attr_reader :pairs

  def to_a
    @pairs = RetainedArray.new(super)
  end
end

class PairLike
  attr_reader :pair, :calls

  def initialize(pair)
    @pair, @calls = pair, 0
  end

  def to_ary
    @calls += 1
    pair
  end
end

class PathString < String; end
Package = Struct.new(:integrity)
Map = Struct.new(:packages) do
  def preloaded_module_packages(**) = packages
end
Request = Struct.new(:nonce, :calls) do
  def content_security_policy_nonce
    self.calls += 1
    nonce
  end
end

view = ActionView::Base.empty
view.extend(Importmap::ImportmapTagsHelper)
request = Request.new(+"nonce<&", 0)
view.define_singleton_method(:request) { request }
results = {}

%w[array frozen_array array_subclass hash hash_subclass pair_like].each do |kind|
  path = PathString.new("/module?x=<1>&y=2")
  integrity = PathString.new("sha384-<&")
  package = Package.new(integrity)
  pair = [path, package]
  packages = case kind
  when "array" then [pair]
  when "frozen_array" then [pair.each(&:freeze).freeze].freeze
  when "array_subclass" then RetainedArray.new([pair])
  when "hash" then {path => package}.freeze
  when "hash_subclass" then RetainedHash[path => package]
  when "pair_like" then [PairLike.new(pair)]
  end
  first = view.javascript_importmap_module_preload_tags(Map.new(packages))
  original = first.dup
  collected = packages.is_a?(RetainedHash) ? packages.pairs : packages
  retained = collected.collected if collected.is_a?(RetainedArray)
  replay = collected.operation.call(pair) if retained
  retained&.clear
  first << "caller mutation"
  second = view.javascript_importmap_module_preload_tags(Map.new(packages))
  raise "caller output/input alias" unless second == original && first != second
  raise "input pair mutated" unless pair == [path, package]
  raise "frozen input changed" if kind == "frozen_array" && !packages.frozen?
  results[kind] = [original, second, first.class.name, first.html_safe?, first.frozen?,
    replay, kind == "pair_like" ? packages.first.calls : nil]
end

path = PathString.new("/first.js")
paths = [path].freeze
first = view.javascript_module_preload_tag(*paths)
path.replace("/second.js")
request.nonce.replace("new nonce")
second = view.javascript_module_preload_tag(*paths)
raise "cached input/output" unless first.include?("/first.js") && !first.include?("/second.js") && second.include?("/second.js")
results["live_paths_and_nonce"] = [first, second]
request = nil
results["nil_request"] = view.javascript_module_preload_tag("/frozen.js".freeze)

# An ordinary overridable tag builder can retain its keyword hashes and the
# returned strings. None may become a shared buffer across calls or links.
events, retained_options, retained_tags = [], [], []
builder = Object.new
builder.define_singleton_method(:link) do |**options|
  events << "link"
  retained_options << options
  value = options.values.join("|").html_safe
  retained_tags << value
  value
end
view.define_singleton_method(:tag) { events << "tag"; builder }
request = Request.new("builder nonce".freeze, 0)
integrity = PathString.new("builder integrity").freeze
package = Object.new
package.define_singleton_method(:integrity) { events << "integrity"; integrity }
packages = [["/a.js".freeze, package].freeze, ["/b.js".freeze, package].freeze].freeze
first = view.javascript_importmap_module_preload_tags(Map.new(packages))
original = first.dup
retained_tags.first.clear
retained_options.first[:href] = "/caller.js"
raise "returned buffer alias" unless first == original
raise "shared keyword hash" unless retained_options.last[:href] == "/b.js"
raise "argument identity lost" unless retained_options.last[:integrity].equal?(integrity)
second = view.javascript_importmap_module_preload_tags(Map.new(packages))
raise "cached tag/hash" unless second == original
results["retained_tag_options"] = {first: first, second: second, events: events, nonce_calls: request.calls,
  distinct_options: retained_options.map(&:object_id).uniq.size == retained_options.size,
  keyword_order: retained_options.map(&:keys)}

File.write(ARGV.fetch(1), JSON.pretty_generate(results) + "\n")
