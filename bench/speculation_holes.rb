# frozen_string_literal: true

# Executable counterexamples, not support claims or production runtime hooks.
require "json"
require_relative "../gem/lib/lowrail"
require_relative "../gem/lib/lowrail/manifest"
require_relative "../gem/lib/lowrail/guard"

results = {}
%w[suppressed_callback conditional_super own_visibility singleton_callback].each do |kind|
  Object.send(:remove_const, :SpeculationHoleHost) if Object.const_defined?(:SpeculationHoleHost)
  Object.const_set(:SpeculationHoleHost, Class.new { def foo = 7 })
  klass = SpeculationHoleHost
  object = klass.new
  original = klass.instance_method(:foo)
  fact = { "receiver" => "@self", "method" => "foo", "owner" => "SpeculationHoleHost", "visibility" => "public",
    "source_location" => original.source_location.join(":") }
  manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
    "files" => {}, "units" => [{ "id" => 0, "facts" => [fact] }] }, "/tmp")
  Lowrail::V.clear
  Lowrail::Guard.install(manifest)
  raise "boot fact false" unless Lowrail.ok?(0, klass)
  case kind
  when "suppressed_callback"
    klass.define_singleton_method(:method_added) { |_| }
    klass.define_method(:foo) { 19 }
  when "conditional_super"
    klass.singleton_class.class_eval do
      def method_added(name)
        return if name == :foo
        super
      end
    end
    raise "missing invokesuper control" unless RubyVM::InstructionSequence.of(klass.method(:method_added)).disasm.include?("invokesuper")
    klass.define_method(:foo) { 19 }
  when "own_visibility"
    klass.send(:private, :foo)
  when "singleton_callback"
    object.define_singleton_method(:singleton_method_added) { |_| }
    object.define_singleton_method(:foo) { 29 }
  end
  # A monomorphic class+epoch cache would return the same stale result. The
  # per-fact residual checks must remain; object lookup catches an override
  # whose callback deliberately did not reach Lowrail's weak tracker.
  exact = Object.const_get(:SpeculationHoleHost).equal?(klass) &&
    object.method(:foo).unbind == original && object.singleton_class.public_method_defined?(:foo)
  results[kind] = { cached_guard: Lowrail.ok?(0, klass), exact_residual: exact,
    original_definition: original.bind_call(object), actual: begin object.public_send(:foo); rescue NoMethodError; "NoMethodError"; end }
end

# Define the replacement BEFORE validating: a method-definition hook while
# constructing it after validation would independently reset the fact and
# accidentally turn this into a passing constant-invalidation experiment.
module SpeculationConstant
  class Original; def self.foo = 7; end
  class Replacement; def self.foo = 23; end
  Target = Original
end
original = SpeculationConstant::Target.method(:foo)
fact = { "receiver" => "SpeculationConstant::Target", "method" => "foo", "singleton" => true,
  "owner" => "#<Class:SpeculationConstant::Original>", "visibility" => "public",
  "source_location" => original.source_location.join(":") }
manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
  "files" => {}, "units" => [{ "id" => 0, "facts" => [fact] }] }, "/tmp")
Lowrail::G.clear
Lowrail::Guard.install(manifest)
raise "constant boot fact false" unless Lowrail.check(0)
SpeculationConstant.send(:remove_const, :Target)
SpeculationConstant.const_set(:Target, SpeculationConstant::Replacement)
results["constant_replacement"] = { cached_guard: Lowrail.check(0),
  exact_residual: SpeculationConstant::Target.equal?(SpeculationConstant::Original),
  original: 7, actual: SpeculationConstant::Target.foo }

module SpeculationConstCallback
  @events = []
  def self.events = @events
  def self.const_added(name)
    @events << name.to_s
    super
  end
end
SpeculationConstCallback.const_set(:Token, 1)
added = SpeculationConstCallback.events.dup
SpeculationConstCallback.const_set(:Token, 2)
replaced = SpeculationConstCallback.events.dup
SpeculationConstCallback.send(:remove_const, :Token)
callbacks = { added: added, replaced: replaced, removed: SpeculationConstCallback.events.dup }
raise "const_added expectation changed" unless callbacks == { added: ["Token"], replaced: ["Token", "Token"], removed: ["Token", "Token"] }

config = { limit: 7 }
snapshot = config.dup.freeze
epoch = 0
config[:limit] = 31
results["direct_mutation"] = { epoch_unchanged: epoch == 0, same_identity: config.equal?(config),
  exact_residual: config == snapshot, original: snapshot[:limit], actual: config[:limit] }
raise "counterexample or residual check failed" unless results.values.all? { !_1.fetch(:exact_residual) }
puts JSON.pretty_generate(holes: results, const_added: callbacks)
