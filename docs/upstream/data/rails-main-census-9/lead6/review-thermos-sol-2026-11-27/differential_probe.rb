# frozen_string_literal: true

load File.expand_path("../../../../../../bench/upstream/k1/keys_probe.rb", __dir__)

def capture_result
  value = yield
  ["ok", value]
rescue StandardError => error
  [error.class.name, error.message.lines.first.strip.gsub(/0x[0-9a-f]+/, "0xADDR")]
end

def attribute_result(set, name)
  attribute = set[name]
  [attribute.class.name, attribute.name, attribute.initialized?, attribute.came_from_user?,
    capture_result { attribute.value_before_type_cast }, capture_result { attribute.value }]
end

class ProbeString < String
  def to_str = raise("unexpected conversion")
  def to_s = raise("unexpected conversion")
end

class ProbeName
  attr_reader :calls

  def initialize(&callback)
    @calls = []
    @callback = callback
  end

  def hash
    @calls << :hash
    @callback&.call
    "title".hash
  end

  def eql?(other)
    @calls << [:eql, other]
    other == "title"
  end

  def to_s = raise("unexpected conversion")
  private
    def to_str = raise("unexpected private conversion")
end

factories = {
  "loaded" => -> { Post.first },
  "partial" => -> { Post.select(:id, :title).first },
  "no id" => -> { Post.select(:title).first },
  "extra" => -> { Post.select("posts.*, 17 AS extra").first },
  "extra only" => -> { Post.select("id, 17 AS extra").first },
  "new" => -> { Post.new },
  "new assigned" => -> { Post.new(title: "asymmetric", score: 19, note: "note") },
  "assigned" => -> { Post.first.tap { |p| p.title = "assigned"; p.score = nil } },
  "frozen" => -> { Post.first.freeze },
  "partial frozen" => -> { Post.select(:id, :title).first.freeze },
  "new frozen" => -> { Post.new.freeze },
  "dup" => -> { Post.first.dup },
  "partial dup" => -> { Post.select(:id, :title).first.dup },
  "clone" => -> { Post.first.clone },
  "becomes" => -> { Post.first.becomes(SpecialPost) },
  "becomes assigned" => -> { Post.first.becomes(SpecialPost).tap { |p| p.special = "other" } },
  "sti becomes" => -> { Car.first.becomes(Truck) },
  "saved" => -> { Post.first.tap { |p| p.update!(score: 23) } },
  "marshal" => -> { Marshal.load(Marshal.dump(Post.first)) },
  "YAML" => -> { YAML.unsafe_load(YAML.dump(Post.first)) }
}

names = ["id", "title", "score", "note", "extra", "unknown", :title, :unknown, nil, 0,
  "title".dup.freeze, ProbeString.new("title"), ProbeString.new("missing")]
factories.each do |state, build|
  names.each_with_index do |name, i|
    record = build.call
    set = set_of(record)
    results = 2.times.map { capture_result { attribute_result(set, name) } }
    puts ["brackets", state, i, results, capture_result { set.keys },
      capture_result { record.changed? }, capture_result { record.attributes }].to_yaml
  end
end

factories.slice("loaded", "partial", "frozen", "dup", "becomes").each do |state, build|
  record = build.call
  set = set_of(record)
  name = ProbeName.new
  result = capture_result { attribute_result(set, name) }
  puts ["duck name", state, result, name.calls].to_yaml
end

record = Post.first
set = set_of(record)
name = ProbeName.new { record.title = "mutated during hash" }
puts ["reentrant name", capture_result { attribute_result(set, name) }, name.calls,
  record.title, set.keys].to_yaml

record = Post.first
set = set_of(record)
name = ProbeName.new { Fiber.yield(:hash_boundary) }
fiber = Fiber.new { capture_result { attribute_result(set, name) } }
boundary = fiber.resume
record.title = "changed while suspended"
result = fiber.resume
puts ["fiber name", boundary, result, name.calls, record.title, set.keys].to_yaml

class ProbeIndexes < Hash
  attr_reader :calls

  def initialize(other)
    super()
    update(other)
    @calls = []
  end

  def [](name)
    @calls << [:read, name]
    super
  end

  def keys
    @calls << :keys
    super.freeze.dup
  end
end

record = Post.select(:id, :title).first
set = set_of(record)
indexes = ProbeIndexes.new(set.indexes)
set.instance_variable_set(:@indexes, indexes)
puts ["indexes subclass", attribute_result(set, "title"), set.keys, indexes.calls].to_yaml

record = Post.select(:id, :title).first
set = set_of(record)
record.title
set["score"]
set.instance_variable_get(:@attributes).freeze
puts ["frozen cache", capture_result { attribute_result(set, "note") },
  capture_result { set.keys }].to_yaml

puts "EXTENDED_PROBE_COMPLETE"
