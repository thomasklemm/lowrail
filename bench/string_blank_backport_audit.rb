# frozen_string_literal: true

# Design gate, NOT a pass or an app patch. Supply Rails main object/blank.rb
# at 3f0b675158e8284241bb1213c00375bc1fb9c52f. Only String#blank?'s body is
# substituted in the installed 8.1.4 file's ISeq; all other source stays old.
# Usage: mise exec -- ruby bench/string_blank_backport_audit.rb MAIN_BLANK_RB
require "active_support/core_ext/object/blank"
require "prism"
require "json"
require "digest"

def blank_node(source)
  tree = Prism.parse(source, version: "current").value
  string = tree.statements.body.find { _1.is_a?(Prism::ClassNode) && _1.constant_path.location.slice == "String" }
  string.body.body.find { _1.is_a?(Prism::DefNode) && _1.name == :blank? }
end

original = String.instance_method(:blank?)
path = original.source_location.first
source = File.binread(path)
main = File.binread(ARGV.fetch(0))
raise "not audited 8.1.4" unless Digest::SHA256.hexdigest(source) == "203eefc5b094f4a0f5bf68b4c34198891127f52ed7825e146c2fa089a46f8ec7"
raise "not audited main" unless Digest::SHA256.hexdigest(main) == "3c63339d8b7a246c6fa4c7ebe0ffb6450c96473458d9cf3b40b1039abbb72410"
node = blank_node(source)
replacement = source.dup
replacement[node.location.start_offset...node.location.end_offset] = blank_node(main).location.slice
# Re-evaluate the original file (in this disposable process only), keeping
# its lexical constants and frozen-source directive, not a subclass wrapper.
String.send(:remove_const, :BLANK_RE)
String.send(:remove_const, :ENCODED_BLANKS)
RubyVM::InstructionSequence.compile(replacement, path, path, 1).eval
candidate = String.instance_method(:blank?)

if ENV["BLANK_FRAMEWORK_TEST"]
  # Run Rails' own installed-body tests, not just this finite fuzzer.
  require File.expand_path(ENV.fetch("BLANK_FRAMEWORK_TEST"))
  exit
end

def outcome(method, receiver)
  ["return", method.bind_call(receiver)]
rescue StandardError => error
  ["raise", error.class.name, error.message]
end

seed = 41231
random = Random.new(seed)
classes = [String, Class.new(String)]
counts = Hash.new(0)
failures = []
compare = ->(text, group) do
  classes.product([false, true]).each do |klass, frozen|
    value = klass.new(text)
    value.freeze if frozen
    old, new = [original, candidate].map { outcome(_1, value) }
    counts[group] += 1
    if old != new && failures.size < 20
      failures << {group: group, encoding: text.encoding.name, bytes: text.bytes.first(32), size: text.bytesize, frozen: frozen, old: old, new: new}
    end
  end
end
whitespace = [9, 10, 11, 12, 13, 32, 0x85, 0xa0, 0x1680, *(0x2000..0x200a), 0x2028, 0x2029, 0x202f, 0x205f, 0x3000]
boundaries = [0, 8, 14, 31, 33, 0x180e, 0x200b, 0x2060, 0xfeff, 0x1f600]
Encoding.list.each do |encoding|
  (0..255).each { compare.call([_1].pack("C").force_encoding(encoding), "single_byte") }
  ["", *whitespace.map { [_1].pack("U") }, *boundaries.map { [_1].pack("U") }, " \t\n\r\v\f", " x "].each do |text|
    begin
      converted = text.encode(encoding)
    rescue EncodingError
      next
    end
    compare.call(converted, "unicode_boundary")
  end
  300.times do
    text = Array.new(random.rand(0..64)) { random.rand(256) }.pack("C*").force_encoding(encoding)
    compare.call(text, "seeded_bytes")
  end
end
[" " * 1_000_000, " " * 999_999 + "x", "x" + " " * 999_999, "\u3000" * 100_000].each do |text|
  [Encoding::UTF_8, Encoding::UTF_16LE, Encoding::ISO_8859_1].each do |encoding|
    begin
      converted = text.encode(encoding)
    rescue EncodingError
      next
    end
    compare.call(converted, "long")
  end
end

# Counterexamples are observable public behavior, not guard internals. Warm
# first, then suppress the owner's callback, exactly like the quarantine probe.
probes = {}
{ascii_only_override: [:ascii_only?, -> { true }, "\u3000"],
 getbyte_override: [:getbyte, ->(*) { 120 }, " "],
 new_dispatch_exception: [:ascii_only?, -> { raise "new dispatch" }, "x"]}.each do |name, (method, body, text)|
  klass = Class.new(String)
  value = klass.new(text)
  2.times { outcome(original, value); outcome(candidate, value) }
  klass.define_singleton_method(:method_added) { |_| }
  klass.define_method(method, &body)
  probes[name] = [original, candidate].map { outcome(_1, value) }
end
regexp = String::BLANK_RE
String.send(:remove_const, :BLANK_RE)
String.const_set(:BLANK_RE, /\Anever\z/)
probes[:replaced_blank_re] = [original, candidate].map { outcome(_1, " ") }
String.send(:remove_const, :BLANK_RE)
String.const_set(:BLANK_RE, regexp)
begin
  # Already-existing policy, ordinary native Strings: no suppressed hook or
  # post-seal method/constant mutation can explain away a skipped exception.
  timeout = Regexp.timeout
  Regexp.timeout = 0.000001
  [" " * 1_000_000, " " * 999_999 + "x"].each_with_index do |text, i|
    probes["preexisting_timeout_#{i}"] = [original, candidate].map { outcome(_1, text) }
  end
ensure
  Regexp.timeout = timeout
end
begin
  timeout = Regexp.timeout
  Regexp.timeout = nil
  String.send(:remove_const, :BLANK_RE)
  String.const_set(:BLANK_RE, Regexp.new(regexp.source, regexp.options, timeout: 0.000001).freeze)
  probes[:preexisting_regexp_timeout] = [original, candidate].map { outcome(_1, " " * 1_000_000) }
ensure
  String.send(:remove_const, :BLANK_RE)
  String.const_set(:BLANK_RE, regexp)
  Regexp.timeout = timeout
end
events = []
saved_match = Regexp.instance_method(:match?)
Regexp.define_singleton_method(:method_added) { |_| }
Regexp.define_method(:match?) { |value| events << :match; saved_match.bind_call(self, value) }
probes[:regexp_observation] = [original, candidate].map do |method|
  events.clear
  [outcome(method, "x"), events.dup]
end
Regexp.send(:define_method, :match?, saved_match)
Regexp.singleton_class.send(:remove_method, :method_added)

probes[:blank_redefinition] = [original, candidate].map do |method|
  String.send(:define_method, :blank?, method)
  2.times { "x".blank? }
  String.define_singleton_method(:method_added) { |_| }
  String.send(:define_method, :blank?) { :changed_after_warmup }
  "x".blank?
end
String.send(:define_method, :blank?, original)
String.singleton_class.send(:remove_method, :method_added)
puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, seed: seed, upstream: "3f0b675158e8284241bb1213c00375bc1fb9c52f",
  sources: {old: Digest::SHA256.hexdigest(source), main: Digest::SHA256.hexdigest(main)}, encodings: Encoding.list.size,
  counts: counts, ordinary_failures: failures, probes: probes,
  guardless_exact: failures.empty? && probes.values.all? { _1[0] == _1[1] })
