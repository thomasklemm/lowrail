# Prototype, measurement only: per-unit monomorphic class cache (K) in front of
# Lowrail.ok?. Run: ruby --disable-yjit -Igem/lib bench/experiments/guard_inline_cache.rb MODE N
# Modes: none (no guard), cur (today), ic/ic2/ic3/ic4 (variants).
# Callgrind, interpreter, (N=200000 minus N=0)/N: none 300, cur 1103, ic2 640, ic4 658 Ir/iter.
# YJIT min ns/iter: none 24.8, cur 36.5, ic2 23.0.
# Not exact as written: K is never reset (must be cleared with V in
# Guard.reset_method), and ic2 dispatches Class#== on the cached class.
# Prototype: per-unit monomorphic class cache in front of Lowrail.ok?
require "lowrail"
require "lowrail/manifest"
require "lowrail/guard"
class GuardProbe; def foo = 1; end
fact = { "receiver" => "@self", "method" => "foo", "owner" => "GuardProbe", "visibility" => "public",
         "source_location" => GuardProbe.instance_method(:foo).source_location.join(":") }
m = Lowrail::Manifest.new({ "format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
  "files" => {}, "units" => [{ "id" => 0, "facts" => [fact] }] }, "/tmp")
Lowrail::Guard.install(m)
module Lowrail
  NoClass = Class.new
  K = Array.new(8, NoClass) # K[id] = last class that validated true (prototype)
  def self.ok_k?(id, klass)
    s = ok?(id, klass)
    K[id] = klass if s
    s
  end
end
class GuardProbe
  def cur = ::Lowrail.ok?(0, self.class) ? 1 : 2
  def ic  = ((k = self.class).equal?(::Lowrail::K[0]) || ::Lowrail.ok_k?(0, k)) ? 1 : 2
  def ic2 = (::Lowrail::K[0] == self.class || ::Lowrail.ok_k?(0, self.class)) ? 1 : 2
  def none = 1
  def ic4 = (instance_of?(::Lowrail::K[0]) || ::Lowrail.ok_k?(0, self.class)) ? 1 : 2
  def ic3 = ((k = self.class).equal?(::Lowrail::K[0]) || ::Lowrail.ok_k?(0, k)) ? 1 : 2
end
o = GuardProbe.new
mode = ARGV[0]; n = Integer(ARGV[1])
eval <<~R
  def run(o, n)
    i = 0
    while i < n
      o.#{mode}
      i += 1
    end
  end
R
run(o, 1000)
run(o, n)
