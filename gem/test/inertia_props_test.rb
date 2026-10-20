# frozen_string_literal: true

require_relative "test_helper"

class InertiaPropsTest < Minitest::Test
  include LowrailTest

  SCENARIO = <<~'RUBY'
    gem "inertia_rails", ENV.fetch("INERTIA_VERSION")
    require "rails"
    require "action_controller/railtie"
    require "inertia_rails"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/guard"
    require "lowrail/stats"
    require "lowrail/inertia_props_build"
    klass = InertiaRails::PropsResolver
    built = Lowrail::InertiaPropsBuild.build
    raise built.inspect unless built[:units].size == 1
    unit = built[:units].first.merge("id" => 0)
    unit["data"]["sources"].transform_values! { "stale" } if ENV["STALE"]
    unit["data"].delete("sources") if ENV["MALFORMED"]
    manifest = Lowrail::Manifest.new({"format" => 1, "ruby_description" => RUBY_DESCRIPTION,
      "compile_option" => Lowrail::Manifest.compile_option_fingerprint, "files" => {}, "units" => [unit]}, Dir.pwd)
    Lowrail::Stats.enable!
    Lowrail::Guard.install(manifest, Lowrail::Stats::STATE)
    Lowrail::Passes::InertiaProps.install(manifest.units)
    Lowrail::Passes::InertiaProps.activate
    unless ENV["PLAIN"]
      file = built[:files].first
      code = file[:parts].map { Integer === _1 ? "0" : _1 }.join
      RubyVM::InstructionSequence.load_from_binary(RubyVM::InstructionSequence.compile(code, file[:path], file[:path]).to_binary).eval
    end
    if ENV["RACTOR"]
      result = Ractor.new do
        evaluator = InertiaRails::PropEvaluator.new(Object.new)
        InertiaRails::PropsResolver.new({ odd: 7, nested: { even: 12 } }, evaluator: evaluator).resolve
      end.value
      puts JSON.generate(result: result)
      exit
    end
    calls = []
    evaluator = InertiaRails::PropEvaluator.new(Object.new)
    leaf = { odd: 7, even: 12 }
    props = { text: "雪<&", values: [3, nil, false], lazy: -> { calls << "lazy"; { fresh: 31 } },
      unwrap: -> { calls << "unwrap"; InertiaRails.always { calls << "inner"; 19 } },
      once: InertiaRails.once { 23 }, deferred: InertiaRails.defer { 29 },
      merged: InertiaRails.merge { [37] },
      scroll: InertiaRails.scroll(page_name: "page", previous_page: nil, next_page: 3, current_page: 2) { [41] },
      json: InertiaRails.defer(rescue: true) { 59 },
      rescued: InertiaRails.defer(rescue: true) { calls << "error"; raise "expected" },
      nested: leaf, empty: {}, blank: nil }
    serializer = Object.new
    serializer.define_singleton_method(:to_inertia) { calls << "serializer"; { serialized: 43 } }
    serializer.define_singleton_method(:to_json) { |*| JSON.generate("unserialized") }
    props[:serialized] = serializer
    props[:lazy_serializer] = -> { calls << "lazy_serializer"; serializer }
    props[:lazy_scroll] = -> { InertiaRails.scroll(page_name: "page", previous_page: 1, next_page: nil, current_page: 2) { [61] } }
    # A later, distinct recursive entry must use a mutated actual iterator.
    # The current iterator is already executing: restarting the whole method
    # would evaluate lazy props/serializers/recorders twice.
    destination = ENV["SUBCLASS"] ? Class.new(Hash)[target: 47] : { target: 47 }
    props[:destination] = destination
    recorder = Object.new
    recorder.define_singleton_method(:prop_resolved) { |path, _, **| calls << "record/#{path}" }
    recorder.define_singleton_method(:serializer_found) { |_, path| calls << "found/#{path}" }
    point = ENV["POINT"]
    spelling, occurrence = point.to_s.split(":")
    occurrence = Integer(occurrence || "1")
    seen = 0
    mutations = 0
    mutate = -> {
      mutations += 1
      destination.define_singleton_method(:singleton_method_added) { |_| } # deliberately suppress Guard's hook
      if ENV["MUTATE"] == "each"
        original = Hash.instance_method(:each)
        destination.define_singleton_method(:each) { |&block| original.bind_call(self, &block); block.call(:changed, 53); self }
      elsif ENV["MUTATE"] == "private"
        destination.singleton_class.send(:private, :each_with_object)
      else
        original = Enumerable.instance_method(:each_with_object)
        destination.define_singleton_method(:each_with_object) { |memo, &block| original.bind_call(self, memo, &block); memo[:changed] = 53; memo }
      end
    }
    # Warm the authorization before changing a fact without invalidation.
    klass.new({ warm: 1 }, evaluator: evaluator).resolve
    Lowrail::Stats.reset_counts!
    inside = 0
    counts = Hash.new(0)
    boundaries = {}
    trace = TracePoint.new(:b_call, :b_return, :call, :c_call) do |event|
      if event.path == unit.fetch("file") && event.method_id == :deep_transform_props
        inside += 1 if event.event == :b_call
        inside -= 1 if event.event == :b_return
      end
      if inside.positive? && %i[call c_call].include?(event.event)
        caller = caller_locations(event.event == :call ? 2 : 1, 1).first
        if caller&.path == unit.fetch("file") && caller.base_label == "deep_transform_props"
          name = event.method_id.to_s
          counts[name] += 1
          # Original-source discovery covers every exercised body callsite,
          # not just each distinct method name. First/last also cover both
          # short-circuit calls sharing a line and pre/post lazy evaluation.
          unless %w[each each_with_object].include?(name)
            (boundaries[[caller.lineno, name]] ||= []) << "#{name}:#{counts[name]}"
          end
          if mutations.zero? && name == spelling
            seen += 1
            mutate.call if seen == occurrence
          end
        end
      end
    end
    trace.enable if point || ENV["DISCOVER"]
    visit = {component: true}
    result = begin
      klass.new(props, evaluator: evaluator, visit: visit, **(ENV["INERTIA_VERSION"] == "3.23.0" ? {recorder: recorder} : {})).resolve
    rescue NoMethodError => e
      [e.class.name, e.name.to_s]
    ensure
      trace.disable
    end
    raise "unexercised boundary #{point}" if point && mutations != 1
    raise "repeated evaluation" unless calls.count("lazy") == 1 && calls.count("unwrap") == 1 && calls.count("inner") == 1
    later = begin
      klass.new({destination: destination}, evaluator: evaluator).resolve
    rescue NoMethodError => e
      [e.class.name, e.name.to_s]
    end
    # Public resolver semantics: partial/except/once/deferred/dotted props,
    # nested values and result freshness, without sharing per-request output.
    simple = { "auth.name" => "live", "auth.id" => 17, lazy: -> { { odd: 7, even: 12 } } }
    controls = [{}, {component: true, only: ["auth.name", "lazy.odd"]}, {component: true, except: ["auth.id"]},
      {except_once: ["once"]}].map do |v|
      a = klass.new(simple, evaluator: evaluator, visit: v).resolve
      b = klass.new(simple, evaluator: evaluator, visit: v).resolve
      raise "shared result" if a.equal?(b) || a[0].equal?(b[0])
      a
    end
    puts JSON.generate(result: result, later: later, calls: calls, controls: controls, mutations: mutations,
      hits: Lowrail::Stats.unit_hits, fallbacks: Lowrail::Stats.unit_fallbacks,
      boundaries: boundaries.values.flat_map { [_1.first, _1.last] }.uniq)
  RUBY

  def test_public_contract_and_every_post_entry_dispatch_boundary
    skip_unless_installed
    %w[3.21.2 3.22.0 3.23.0].each do |version|
      discovery = ruby_json(SCENARIO, env: {"INERTIA_VERSION" => version, "PLAIN" => "1", "DISCOVER" => "1"})
      points = discovery.fetch("boundaries")
      assert_operator points.size, :>, 30
      [nil, *points].each do |point|
        env = {"INERTIA_VERSION" => version, "POINT" => point}
        plain = ruby_json(SCENARIO, env: env.merge("PLAIN" => "1"))
        actual = ruby_json(SCENARIO, env: env)
        %w[result later calls controls mutations].each { |key| assert_equal plain[key], actual[key], "#{version}/#{point}/#{key}" }
        assert_operator actual["hits"].fetch("0", 0), :>, 0
        assert_equal({"auth" => {"name" => "live"}, "lazy" => {"odd" => 7, "even" => 12}}, actual["controls"][1][0])
        assert_equal 53, actual["later"][0]["destination"]["changed"] if point
      end
    end
  end

  def test_each_mutation_private_visibility_and_stale_fallback
    skip_unless_installed
    [{"MUTATE" => "each"}, {"MUTATE" => "private"}, {"SUBCLASS" => "1"}, {"STALE" => "1"}, {"MALFORMED" => "1"}].each do |mode|
      env = {"INERTIA_VERSION" => "3.23.0", "POINT" => "call"}.merge(mode)
      plain = ruby_json(SCENARIO, env: env.merge("PLAIN" => "1"))
      actual = ruby_json(SCENARIO, env: env)
      %w[result later calls controls mutations].each { |key| assert_equal plain[key], actual[key], mode.inspect }
      assert_equal({}, actual["hits"]) if mode["STALE"] || mode["MALFORMED"]
    end
  end

  def test_nonmain_ractor_keeps_the_original_resolver
    skip_unless_installed
    env = {"INERTIA_VERSION" => "3.23.0", "RACTOR" => "1"}
    plain = ruby_json(SCENARIO, env: env.merge("PLAIN" => "1"))
    assert_equal plain, ruby_json(SCENARIO, env: env)
    assert_equal({"odd" => 7, "nested" => {"even" => 12}}, plain["result"][0])
  end

  private

  def skip_unless_installed
    skip "install supported inertia_rails versions" unless %w[3.21.2 3.22.0 3.23.0].all? { Gem::Specification.find_all_by_name("inertia_rails", _1).any? }
  end
end
