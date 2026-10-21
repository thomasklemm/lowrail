# frozen_string_literal: true

# Pre-implementation specimen only, never required by the runtime or a builder.
# Keep the exact actual-receiver guard at EVERY recursive iterator entry.
# --check reuses the public resolver's existing lifetime/mutation fixture.
# Pricing is the separate yjit_regression.rb props_variant cohort, not this gate.
require "prism"

module PropsVariant
  def self.source(original, shape:, id: 0)
    nodes = Lowrail::InertiaPropsBuild::Definitions.new
    Prism.parse(original).value.accept(nodes)
    node = nodes.nodes.find { _1.name == :deep_transform_props }
    raise "missing audited resolver" unless node
    definition = node.location.slice
    header = definition.lines.first.chomp
    body = node.body.location.slice
    guard = "::Lowrail::Passes::InertiaProps.valid?(#{Integer(id)}, props)"
    replacement = case shape
    when "split"
      raise "fallback name collision" if original.include?("deep_transform_props_lowrail_original")
      needle = "props.each_with_object({}) do |(key, prop), transformed_props|"
      raise "unknown iterator" unless body.start_with?(needle)
      fast = body.sub(needle, "transformed_props = {}; props.each do |key, prop|")
      fallback = definition.sub("def deep_transform_props(", "def deep_transform_props_lowrail_original(")
      <<~RUBY.chomp
        #{header}
              return deep_transform_props_lowrail_original(props, prefix, parent_was_resolved: parent_was_resolved) unless #{guard}
              #{fast}
              transformed_props
            end

            #{fallback}
      RUBY
    when "checks_original"
      # Deliberately retain the ORIGINAL work after every exact guard. The
      # paired difference prices checks with their real recursive frequency,
      # fresh root Hashes and singleton-class side effects, not one root check.
      definition.sub(header, "#{header}\n      #{guard}")
    else
      raise ArgumentError, "unknown props specimen #{shape}"
    end
    result = original.byteslice(0...node.location.start_offset) + replacement +
      original.byteslice(node.location.end_offset..)
    raise "invalid specimen" unless Prism.parse(result).success?
    result
  end
end

if $PROGRAM_NAME == __FILE__
  require "json"
  require "open3"
  require "rbconfig"
  require "fileutils"
  require "digest"
  require_relative "../jit_stability"
  mode, out = ARGV
  abort "usage: props_variant.rb --check NEW_OUTDIR (BENCH_JIT=0|1)" unless mode == "--check" && out
  out = File.expand_path(out)
  raise "output must be new" if File.exist?(out)
  FileUtils.mkdir_p(out, mode: 0o700)
  fixture_path = File.expand_path("../../gem/test/inertia_props_test.rb", __dir__)
  sources = [File.expand_path(__FILE__), fixture_path,
    *Dir[File.expand_path("../../gem/lib/lowrail/{inertia_props*,guard,manifest,stats}.rb", __dir__)]
  ].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
  fixture = File.read(fixture_path)
    .split("SCENARIO = <<~'RUBY'\n", 2).fetch(1).split("\n  RUBY", 2).first
  installation = 'code = file[:parts].map { Integer === _1 ? "0" : _1 }.join'
  raise "fixture installation changed" unless fixture.include?(installation)
  prefix = <<~RUBY
    require 'json'
    require #{File.expand_path(__FILE__).dump}
    require #{File.expand_path('../jit_stability', __dir__).dump}
    JitStability.assert_mode!
    at_exit { puts "PROPS_VARIANT_JIT \#{JSON.generate(JitStability.state)}" }
  RUBY
  fixture = prefix + fixture.sub(installation,
    "code = ENV['PROPS_VARIANT'] ? PropsVariant.source(file[:original], shape: ENV.fetch('PROPS_VARIANT')) : file[:parts].map { Integer === _1 ? '0' : _1 }.join")
  fixture = fixture.sub('unless ENV["PLAIN"]', "parameters = klass.instance_method(:deep_transform_props).parameters\n    unless ENV[\"PLAIN\"]")
    .sub('if ENV["RACTOR"]', <<~RUBY)
      raise 'changed signature' unless klass.instance_method(:deep_transform_props).parameters == parameters
      raise 'changed visibility' unless klass.private_method_defined?(:deep_transform_props)
      raise 'public fallback' if klass.public_method_defined?(:deep_transform_props_lowrail_original)
      if ENV['RACTOR']
    RUBY
  # Observe the same original-body boundaries after moving it to its own def.
  fixture = fixture.sub("event.method_id == :deep_transform_props",
    "%i[deep_transform_props deep_transform_props_lowrail_original].include?(event.method_id)")
    .sub('caller.base_label == "deep_transform_props"',
      '%w[deep_transform_props deep_transform_props_lowrail_original].include?(caller.base_label)')
  warmup = "klass.new({ warm: 1 }, evaluator: evaluator).resolve"
  raise "fixture warmup changed" unless fixture.include?(warmup)
  fixture = fixture.sub(warmup, <<~RUBY)
    #{warmup}
    if ENV['CALLBACK']
      200.times { klass.new({ warm: 1, nested: { odd: 7 } }, evaluator: evaluator).resolve }
      if RubyVM::YJIT.enabled?
        iseq = RubyVM::InstructionSequence.of(klass.instance_method(:deep_transform_props))
        raise 'resolver did not compile before callback mutation' unless RubyVM::YJIT.insns_compiled(iseq).any?
      end
      original_lazy = props.fetch(:lazy)
      props[:lazy] = -> { mutate.call; original_lazy.call }
    end
  RUBY
  lib = File.expand_path("../../gem/lib", __dir__)
  records = []
  modes = []
  run = ->(env, label) {
    clean = %w[RUBYOPT RUBY_YJIT_ENABLE RUBY_ZJIT_ENABLE LOWRAIL_ROOT LOWRAIL_DIR LOWRAIL_STATS LOWRAIL_OUTCOMES LOWRAIL_DEBUG
      LOWRAIL_JIT_DIAGNOSTICS LOWRAIL_BUILD_JIT BUNDLE_GEMFILE RAILS_ENV
      PLAIN DISCOVER POINT RACTOR STALE MALFORMED MUTATE SUBCLASS CALLBACK PROPS_VARIANT INERTIA_VERSION].to_h { [_1, nil] }
    stdout, stderr, status = Open3.capture3(clean.merge("LOWRAIL" => "0").merge(env), RbConfig.ruby,
      *JitStability.flags, "-I#{lib}", "-e", fixture)
    File.write(File.join(out, "#{label}.log"), stderr)
    File.write(File.join(out, "#{label}.stdout"), stdout)
    raise "#{label} failed: #{stderr.lines.last(8).join}" unless status.success?
    lines = stdout.lines
    state = JSON.parse(lines.pop.delete_prefix("PROPS_VARIANT_JIT "))
    actual_mode = JitStability.actual(state)
    raise "#{label}: unexpected child mode #{actual_mode}" unless actual_mode == JitStability.mode
    modes << actual_mode
    result = JSON.parse(lines.last)
    File.write(File.join(out, "#{label}.json"), JSON.pretty_generate(result.merge("actual_jit" => actual_mode)))
    result
  }
  %w[3.21.2 3.22.0 3.23.0].each do |version|
    base = {"INERTIA_VERSION" => version}
    discovery = run.call(base.merge("PLAIN" => "1", "DISCOVER" => "1"), "#{version}-discover")
    points = discovery.fetch("boundaries")
    raise "lost boundary coverage" unless points.size > 30
    cases = [*([nil, *points].map { {"POINT" => _1} }),
      *%w[each private].map { {"POINT" => "call", "MUTATE" => _1} },
      *%w[SUBCLASS STALE MALFORMED].map { {"POINT" => "call", _1 => "1"} },
      {"CALLBACK" => "1"}, {"RACTOR" => "1"}]
    cases.each_with_index do |condition, index|
      env = base.merge(condition)
      plain = run.call(env.merge("PLAIN" => "1"), "#{version}-#{index}-original")
      %w[split checks_original].each do |shape|
        actual = run.call(env.merge("PROPS_VARIANT" => shape), "#{version}-#{index}-#{shape}")
        keys = condition["RACTOR"] ? %w[result] : %w[result later calls controls mutations]
        keys.each { |key| raise "#{version}/#{condition}/#{shape}/#{key}" unless actual.fetch(key) == plain.fetch(key) }
        unless condition["RACTOR"]
          hits = actual.fetch("hits").fetch("0", 0)
          fallbacks = actual.fetch("fallbacks").fetch("0", 0)
          if condition["STALE"] || condition["MALFORMED"]
            raise "stale guard hit" unless hits.zero?
          else
            raise "no actual fast authorization" unless hits.positive?
          end
          if condition["POINT"] || condition["CALLBACK"]
            raise "missing unsafe-receiver fallback" unless fallbacks.positive?
          else
            raise "unexpected normal fallback" unless fallbacks.zero?
          end
          if (condition["POINT"] || condition["CALLBACK"]) && !condition["MUTATE"]
            raise "lost suppressed-hook mutation" unless actual.fetch("later")[0].fetch("destination").fetch("changed") == 53
          end
          raise "missing callback mutation" if condition["CALLBACK"] && actual.fetch("mutations") != 1
        end
        records << {version: version, shape: shape, condition: condition, pass: true}
      end
    end
  end
  raise "specimen sources changed" unless sources.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
  File.write(File.join(out, "verdict.json"), JSON.pretty_generate(ruby: RUBY_DESCRIPTION,
    requested_jit: JitStability.mode, actual_jit: modes.uniq, sources: sources,
    cases: records.size, records: records, measured: false))
  puts "#{records.size} props variant cases passed (#{modes.uniq.join(', ')}); no measured cohort"
end
