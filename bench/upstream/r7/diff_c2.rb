# Differential harness for C2 (Hash#as_json keys): run in main and candidate, diff.
require "active_support"
require "active_support/core_ext/object/json"

LOG = []
class V
  def initialize(n, &h) = (@n, @h = n, h)
  def as_json(o = nil) = (LOG << "#{@n}.as_json(#{o.inspect})"; @h&.call; @n)
end
class K
  def initialize(n) = @n = n
  def to_s = (LOG << "K(#{@n}).to_s"; @n)
  def hash = @n.hash
  def eql?(o) = o.is_a?(K) && o.to_s == @n
end
class SubStr < String
  def to_s = (LOG << "SubStr#to_s"; "sub!")
end
class SubHash < Hash
  def each(...) = (LOG << "SubHash#each"; super)
end
def describe(h)
  h.map { |k, v| "#{k.inspect}(#{k.class},#{k.frozen?},#{k.encoding},#{k.is_a?(String) && Symbol.all_symbols.any? { |s| s.name.equal?(k) }})=>#{v.inspect}" }.join(" ")
end

dyn = "dyn_#{Process.clock_gettime(Process::CLOCK_REALTIME).to_i % 1}".to_sym
ident = {}.compare_by_identity; ident[:a] = 1; ident["b".dup] = 2
sub = SubHash.new; sub[:x] = V.new("vx"); sub["y"] = 2
mut = { a: 1 }
mut[:b] = V.new("vb") { mut[:zz] = 1 }
frozen = { f: 1, "g" => 2 }.freeze
inputs = {
  "symbols" => { id: 1, name: "n", "with space": 2, é: 3, 日本: 4, dyn => 5 },
  "strings" => { "a" => 1, SubStr.new("s") => 2 },
  "mixed" => { 1 => :one, nil => 2, K.new("k") => V.new("vk"), 1.5 => 3, [:arr] => 4 },
  "identity" => ident,
  "subhash" => sub,
  "frozen" => frozen,
  "mutate" => mut,
  "nested" => { a: { b: { c: V.new("vc") } } },
}
inputs.each do |name, h|
  [nil, {}, { only: [:id, "a", :x] }, { except: :name }, {}.freeze].each do |opts|
    LOG.clear
    r = begin
      res = opts.nil? ? h.as_json : h.as_json(opts)
      "#{res.class} #{describe(res)}"
    rescue => e
      "#{e.class}: #{e.message}"
    end
    puts "#{name} | #{opts.inspect} | #{r} | #{LOG.join(", ")}"
  end
end
