# frozen_string_literal: true

# Mutation/inline-cache counter matrix, not a proposed runtime guard.
# Run with the repository-pinned Ruby; Zeitwerk is an installed corpus gem.
require "json"
require "tmpdir"
require "zeitwerk"

abort "this measurement targets Ruby 4.0.7" unless RUBY_VERSION == "4.0.7"
rows = []
snapshot = -> { RubyVM.stat }
snapshot.call # warm this constant lookup before observing any mutation
observe = ->(label, &operation) do
  before = snapshot.call
  operation.call
  after = snapshot.call
  rows << { case: label, delta: after.to_h { |key, value| [key, value - before.fetch(key)] } }
end
quiet = ->(&operation) do
  previous = $VERBOSE
  $VERBOSE = nil
  operation.call
ensure
  $VERBOSE = previous
end

host = Module.new
Object.const_set(:EpochProbeHostQ70, host)
uncached = :UncachedTargetQ70
host.const_set(uncached, 7)
raise unless host.const_get(uncached) == 7
observe.call("const_get_only/replacement") { quiet.call { host.const_set(uncached, 19) } }
raise unless host.const_get(uncached) == 19
observe.call("const_get_only/remove_const") { host.send(:remove_const, uncached) }
raise if host.const_defined?(uncached, false)

cached = :CachedTargetQ70
host.const_set(cached, 7)
getter = RubyVM::InstructionSequence.compile("::EpochProbeHostQ70::CachedTargetQ70")
raise unless getter.eval == 7
observe.call("inline_cached/replacement") { quiet.call { host.const_set(cached, 23) } }
raise unless getter.eval == 23
observe.call("inline_cached/remove_const") { host.send(:remove_const, cached) }
raise if host.const_defined?(cached, false)

Dir.mktmpdir("lowrail-constant-epoch") do |dir|
  %w[UncachedAutoloadQ70 CachedAutoloadQ70].each do |name|
    file = File.join(dir, "#{name}.rb")
    File.write(file, "module EpochProbeHostQ70; #{name} = Object.new; end\n")
    observe.call("#{name}/register") { host.autoload(name.to_sym, file) }
    lookup = name.start_with?("Cached") ? RubyVM::InstructionSequence.compile("::EpochProbeHostQ70::#{name}") : nil
    value = nil
    observe.call("#{name}/materialize") { value = lookup ? lookup.eval : host.const_get(name) }
    raise unless value && host.autoload?(name).nil?
    observe.call("#{name}/remove_const") { host.send(:remove_const, name) }
    raise if host.const_defined?(name, false)
  end

  # Unmaterialized autoloads can also be removed during a loader reload.
  name = :UnloadedAutoloadQ70
  file = File.join(dir, "unloaded.rb")
  File.write(file, "module EpochProbeHostQ70; UnloadedAutoloadQ70 = 31; end\n")
  host.autoload(name, file)
  observe.call("unmaterialized_autoload/remove_const") { host.send(:remove_const, name) }
  raise if host.const_defined?(name, false)

  %w[Uncached Cached].each do |kind|
    namespace = Module.new
    root_name = "#{kind}ZeitwerkRootQ70"
    host.const_set(root_name, namespace)
    root = File.join(dir, kind.downcase)
    Dir.mkdir(root)
    class_name = "#{kind}ZeitwerkItemQ70"
    File.write(File.join(root, "item.rb"), "class EpochProbeHostQ70::#{root_name}::#{class_name}; end\n")
    loader = Zeitwerk::Loader.new
    loader.enable_reloading
    loader.inflector.inflect("item" => class_name)
    loader.push_dir(root, namespace: namespace)
    loader.setup
    lookup = kind == "Cached" ? RubyVM::InstructionSequence.compile("::EpochProbeHostQ70::#{root_name}::#{class_name}") : nil
    original = lookup ? lookup.eval : namespace.const_get(class_name)
    observe.call("zeitwerk_#{kind.downcase}/reload") { loader.reload }
    replacement = nil
    observe.call("zeitwerk_#{kind.downcase}/rematerialize") { replacement = lookup ? lookup.eval : namespace.const_get(class_name) }
    raise "reload did not replace class" if original.equal?(replacement)
    loader.unload
    loader.unregister
  end
end

counter = :constant_cache_invalidations
%w[const_get_only/replacement const_get_only/remove_const zeitwerk_uncached/reload].each do |label|
  raise "uncached counter expectation changed: #{label}" unless rows.find { _1.fetch(:case) == label }.fetch(:delta).fetch(counter).zero?
end
%w[inline_cached/replacement inline_cached/remove_const zeitwerk_cached/reload].each do |label|
  raise "cached counter expectation changed: #{label}" unless rows.find { _1.fetch(:case) == label }.fetch(:delta).fetch(counter).positive?
end
puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, zeitwerk: Zeitwerk::VERSION, cases: rows,
  conclusion: "constant_cache_invalidations counts registered inline-cache entries cleared, not all constant mutations")
