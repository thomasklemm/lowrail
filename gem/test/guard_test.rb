# frozen_string_literal: true

require_relative "test_helper"

# Every way of changing method resolution must reset the units whose facts
# mention the affected name. Runs in a subprocess because the hooks are
# prepended to Module and BasicObject for the life of the process.
class GuardTest < Minitest::Test
  include LowrailTest

  SCRIPT = <<~'RUBY'
    require "json"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/guard"
    require "lowrail/loader"
    names = %w[foo bar baz qux]
    units = names.each_with_index.map do |n, i|
      { "id" => i, "file" => "/x.rb", "method" => "X#y", "facts" => [{ "receiver" => "Object", "method" => n, "singleton" => false,
        "owner" => "Object", "source_location" => nil, "visibility" => "public" }] }
    end
    manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
                                       "files" => {}, "units" => units }, "/tmp")
    Lowrail::Guard.install(manifest)
    G = Lowrail::G
    results = {}
    check = lambda do |label, expect_reset: true, &blk|
      G.fill(true, 0, names.size)
      blk.call
      reset = G[0].nil?            # every case touches "foo"
      untouched = G[1] == true     # and never "bar"
      results[label] = (reset == expect_reset) && untouched
    end

    class Host; end
    check.("def") { class Host; def foo; end; end }
    check.("define_method") { Host.define_method(:foo) {} }
    check.("alias_method") { Host.alias_method(:foo, :to_s) }
    check.("alias keyword") { class Host; alias foo to_s; end }
    check.("attr_accessor") { Host.attr_accessor :foo }
    check.("remove_method") { Host.remove_method(:foo) }
    check.("undef_method") { Host.define_method(:foo) {}; G[0] = true; Host.undef_method(:foo) }
    check.("def self.") { def Host.foo; end }
    check.("define_singleton_method on class") { Host.define_singleton_method(:foo) {} }
    check.("define_singleton_method on object") { Object.new.define_singleton_method(:foo) {} }
    check.("def obj.") { o = Object.new; def o.foo; end }
    check.("module_function") { Module.new { module_function; def foo; end } }
    m = Module.new { def foo; end }
    check.("include") { Class.new.include(m) }
    check.("prepend") { Class.new.prepend(m) }
    check.("extend object") { Object.new.extend(m) }
    check.("extend class") { Class.new.extend(m) }
    check.("include module whose ancestor defines it") { Class.new.include(Module.new { include m }) }
    check.("include unrelated module", expect_reset: false) { Class.new.include(Module.new { def other; end }) }
    check.("Struct member") { Struct.new(:foo) }
    check.("Data member") { Data.define(:foo) }
    check.("class_eval string") { Host.class_eval("def foo; end") }
    check.("private on inherited method (ZSUPER)") { Class.new(Host).send(:private, :foo) }
    check.("own method_added calling super") do
      Class.new { def self.method_added(n) = super; def foo; end }
    end
    check.("own singleton_method_added calling super") do
      Class.new { def self.singleton_method_added(n) = super; def self.foo; end }
    end
    # Documented holes (PLAN §3.3): pinned so a change in behavior is noticed.
    check.("HOLE: own method_added without super", expect_reset: false) do
      Class.new { def self.method_added(n) = nil; def foo; end }
    end
    check.("HOLE: private on own method", expect_reset: false) { Host.send(:private, :foo) }

    # The no-argument forms of private/public still work with the hooks in.
    k = Class.new { private; def foo; end; public; def bar; end }
    results["private without args still works"] = k.private_method_defined?(:foo) && k.public_method_defined?(:bar)
    puts JSON.generate(results)
  RUBY

  def test_hooks_reset_units
    results = ruby_json(SCRIPT, setup: false, env: { "RUBYOPT" => "-I#{GEM_LIB}" })
    failed = results.reject { |_, ok| ok }.keys
    assert_empty failed, "hooks misbehaved for: #{failed.join(", ")}"
    assert_operator results.size, :>=, 25
  end

  def test_late_yjit_enable_can_replace_a_tracked_array_iterator
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      require "lowrail/guard"
      fact = { "receiver" => "Array", "method" => "each", "owner" => "Array", "source_location" => nil, "visibility" => "public" }
      manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
        "files" => {}, "units" => [{ "id" => 0, "facts" => [fact] }] }, "/tmp")
      Lowrail::Guard.install(manifest)
      RubyVM::YJIT.enable
      sum = 0
      [1, 2, 3].each { sum += _1 }
      puts JSON.generate({ sum: sum, enabled: RubyVM::YJIT.enabled? })
    RUBY
    assert_equal({ "sum" => 6, "enabled" => true }, out)
  end

  def test_per_class_cache_invalidation_and_late_stats_count_each_alias_once
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      require "lowrail/guard"
      require "lowrail/stats" # merely loading Stats must not start counting
      class Base; def foo = 1; end
      class A < Base; end
      class B < Base; end
      fact = { "receiver" => "@self", "method" => "foo", "owner" => "Base",
        "source_location" => Base.instance_method(:foo).source_location.join(":"), "visibility" => "public" }
      manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
        "files" => {}, "units" => [{ "id" => 0, "facts" => [fact] }] }, "/tmp")
      Lowrail::Guard.install(manifest)
      states = [Lowrail.ok?(0, A), Lowrail.view_ok?(0, B)]
      before = Lowrail::Stats.unit_hits
      Lowrail::Stats.enable!
      Lowrail::Stats.enable! # idempotent, including the alias's instrumentation
      states.concat([Lowrail.ok?(0, A), Lowrail.view_ok?(0, B)])
      class B; def foo = 2; end
      states.concat([Lowrail.ok?(0, A), Lowrail.view_ok?(0, B)])
      B.remove_method(:foo)
      states << Lowrail.view_ok?(0, B)
      puts JSON.generate(states: states, before: before, hits: Lowrail::Stats.unit_hits, misses: Lowrail::Stats.unit_fallbacks)
    RUBY
    assert_equal [true, true, true, true, true, false, true], out["states"]
    assert_equal({}, out["before"])
    assert_equal({ "0" => 4 }, out["hits"])
    assert_equal({ "0" => 1 }, out["misses"])
  end

  FACTS_SCRIPT = <<~'RUBY'
    require "json"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/guard"
    module Ext; def find = :ext; end
    class Base
      extend Ext
      def title = "t"
      def self.build = new
      protected def prot = 1
    end
    class Child < Base; end
    def fact(receiver, method, owner, loc, singleton: false, visibility: "public")
      { "receiver" => receiver, "method" => method, "singleton" => singleton, "owner" => owner,
        "source_location" => loc, "visibility" => visibility }
    end
    f = __FILE__
    facts = {
      "instance" => fact("Base", "title", "Base", "#{f}:8"),
      "inherited via subclass receiver" => fact("Child", "title", "Base", "#{f}:8"),
      "singleton own" => fact("Base", "build", "#<Class:Base>", "#{f}:9", singleton: true),
      "singleton from extended module" => fact("Base", "find", "Ext", "#{f}:5", singleton: true),
      "protected" => fact("Base", "prot", "Base", "#{f}:10", visibility: "protected"),
      "cfunc" => fact("Base", "to_s", "Kernel", nil),
      "wrong owner" => fact("Base", "title", "Child", "#{f}:8"),
      "wrong line" => fact("Base", "title", "Base", "#{f}:99"),
      "wrong visibility" => fact("Base", "title", "Base", "#{f}:8", visibility: "private"),
      "missing constant" => fact("Nope", "title", "Nope", nil),
      "missing method" => fact("Base", "nope", "Base", nil),
      "native inherited singleton" => fact("File", "open", "#<Class:IO>", nil, singleton: true)
    }
    units = facts.each_with_index.map { |(k, fa), i| { "id" => i, "file" => "/x.rb", "method" => k, "facts" => [fa] } }
    m = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => "", "compile_option" => "", "files" => {}, "units" => units }, "/tmp")
    Lowrail::Guard.install(m)
    out = {}
    facts.each_key.with_index { |k, i| out[k] = Lowrail::Guard.validate(i) }
    class Child; def title = "c"; end
    out["after subclass override"] = Lowrail::Guard.validate(0)
    native_id = facts.keys.index("native inherited singleton")
    original = File.method(:open)
    File.define_singleton_method(:open) { |*args, &block| original.call(*args, &block) }
    out["native wrapped"] = Lowrail::Guard.validate(native_id)
    File.singleton_class.define_method(:open, original)
    out["native restored copy"] = Lowrail::Guard.validate(native_id)
    File.singleton_class.alias_method(:open, :read)
    out["native different alias"] = Lowrail::Guard.validate(native_id)
    File.singleton_class.remove_method(:open)
    out["native restored lookup"] = Lowrail::Guard.validate(native_id)
    puts JSON.generate(out)
  RUBY

  def test_fact_validation
    r = ruby_json(FACTS_SCRIPT, setup: false, env: { "RUBYOPT" => "-I#{GEM_LIB}" })
    %w[instance inherited\ via\ subclass\ receiver singleton\ own singleton\ from\ extended\ module protected cfunc native\ inherited\ singleton native\ restored\ lookup].each do |k|
      assert r[k], "#{k} should hold"
    end
    %w[wrong\ owner wrong\ line wrong\ visibility missing\ constant missing\ method after\ subclass\ override native\ wrapped native\ restored\ copy native\ different\ alias].each do |k|
      refute r[k], "#{k} should not hold"
    end
  end
end
