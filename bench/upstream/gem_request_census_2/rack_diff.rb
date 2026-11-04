# frozen_string_literal: false

# Differential for the rack set_cookie_header candidate (docs/upstream/gem-request-census-2.md): run once with each
# tree's lib and diff the output. Prints, per input, the header (with encoding and frozenness) or the exception, and
# the conversion hooks called on the value.
#   ruby -I BASE/lib rack_diff.rb > base.txt; ruby -I BRANCH/lib rack_diff.rb > branch.txt; diff base.txt branch.txt
require "rack/utils"

LOG = []
class Probe
  def initialize(s) = @s = s
  def to_s = (LOG << :to_s; @s)
end
class ProbeStr < Probe
  def to_str = (LOG << :to_str; "str-#{@s}")
end
class ProbeAry < Probe
  def to_ary = (LOG << :to_ary; [@s, @s])
end
class SubArray < Array
  def map(&) = (LOG << :sub_map; super)
end
class SubString < String
  def to_s = (LOG << :sub_to_s; super)
end

singleton = +"sing"
def singleton.to_s = (LOG << :singleton_to_s; "S")

values = {
  "plain" => "value",
  "frozen" => "value".freeze,
  "spaces" => "a b+c/d=e&f;g",
  "utf8" => "café",
  "binary" => "\xFF\xFE".b,
  "invalid utf8" => "\xFF".dup.force_encoding("UTF-8"),
  "empty" => "",
  "nil" => nil,
  "false" => false,
  "integer" => 42,
  "symbol" => :sym,
  "array" => %w[va ue],
  "nested array" => [["a", "b"], "c"],
  "empty array" => [],
  "array subclass" => SubArray["x", "y"],
  "string subclass" => SubString.new("sub"),
  "probe to_s" => Probe.new("p"),
  "probe to_str" => ProbeStr.new("p"),
  "probe to_ary" => ProbeAry.new("p"),
  "singleton to_s" => singleton,
  "hash value plain" => { value: "v", path: "/", httponly: true, same_site: :lax },
  "hash value nil" => { path: "/" },
  "hash value array" => { value: %w[a b], domain: "example.com", secure: true },
  "hash value probe" => { value: ProbeStr.new("h") },
  "hash expires" => { value: "v", expires: Time.at(0).utc, max_age: 10, partitioned: true },
  "hash bad same_site" => { value: "v", same_site: :bogus },
}

def show(r) = r.is_a?(String) ? [r, r.encoding.to_s, r.frozen?] : r

values.each do |name, v|
  LOG.clear
  out = begin
    show(Rack::Utils.set_cookie_header("name", v))
  rescue Exception => e
    [e.class, e.message]
  end
  puts "#{name}: #{out.inspect} #{LOG.inspect}"
end

# delete_set_cookie_header and set_cookie_header! go through the same line
puts Rack::Utils.delete_set_cookie_header("name", { path: "/" }).inspect
h = {}; Rack::Utils.set_cookie_header!(h, "a", "1"); Rack::Utils.set_cookie_header!(h, "b", %w[x y]); puts h.inspect
puts Rack::Utils.set_cookie_header(:sym_key, "v").inspect
begin; Rack::Utils.set_cookie_header("bad key", "v"); rescue => e; puts [e.class, e.message].inspect; end

# An overridden public escape that returns non-Strings
module Rack::Utils
  class << self
    alias_method :orig_escape, :escape
  end
end
[->(s) { orig_escape(s) + "!" }, ->(s) { nil }, ->(s) { :sym }, ->(s) { ProbeStr.new(s.to_s) }].each_with_index do |impl, i|
  Rack::Utils.define_singleton_method(:escape, &impl)
  LOG.clear
  out = begin; show(Rack::Utils.set_cookie_header("name", "v")); rescue => e; [e.class, e.message]; end
  puts "override #{i}: #{out.inspect} #{LOG.inspect}"
end
