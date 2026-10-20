# frozen_string_literal: true

# Experimental body delivery only. The constructor itself is NOT wrapped or
# edited: stock TagHelper#tag_builder records the result of its own stock new.
require "json"
require "tmpdir"
require "open3"
require "rbconfig"

module SealedBuilderCost
  BUILDERS = ObjectSpace::WeakKeyMap.new
  ACTIVE = [false]
  SERVED = []
  LIB = File.expand_path("../../gem/lib", __dir__)

  def self.install
    require File.expand_path("config/boot", Dir.pwd)
    $LOAD_PATH.unshift(LIB)
    require "lowrail/compiler"
    path = Gem::Specification.find_by_name("actionview").full_gem_path + "/lib/action_view/helpers/tag_helper.rb"
    raise "TagHelper already loaded" if $LOADED_FEATURES.include?(path)
    source = File.read(path)
    original = "@tag_builder ||= TagBuilder.new(self)"
    replacement = "@tag_builder ||= (begin; __lowrail_builder = TagBuilder.new(self); if ::Ractor.current.equal?(::Ractor.main) && ::SealedBuilderCost::ACTIVE[0]; ::SealedBuilderCost::BUILDERS[__lowrail_builder] = true; end; __lowrail_builder; end)"
    raise "stock factory changed" unless source.scan(original).size == 1
    lowered = source.sub(original, replacement)
    @directory = Dir.mktmpdir("sealed-builder-delivery")
    at_exit { FileUtils.remove_entry(@directory) }
    file = File.join(@directory, "lowered.rb")
    File.write(file, lowered)
    input = {"out" => @directory, "rails_env" => "production",
      "files" => [{"path" => path, "lowered" => file}],
      "units" => [{"id" => 0, "kind" => "file", "pass" => "experiment/sealed_builder",
        "file" => path, "facts" => []}]}
    units = File.join(@directory, "units.json")
    File.write(units, JSON.generate(input))
    _, error, status = Open3.capture3({"LOWRAIL" => "0"}, RbConfig.ruby,
      File.join(LIB, "../exe/lowrail-compile"), units)
    raise "constructor delivery compile failed: #{error}" unless status.success?
    data = JSON.parse(File.read(File.join(@directory, "manifest.json")))
    raise "factory file not compiled: #{error}" unless data.fetch("files").key?(path)
    raise "delivery setup refused" unless Lowrail.setup(root: Dir.pwd, dir: @directory)
    observer = TracePoint.new(:return) do |event|
      SERVED << event.binding.local_variable_get(:path) if event.method_id == :serve &&
        event.self.equal?(Lowrail::Loader) && event.return_value
    end
    observer.enable
    [path, observer]
  end
end

if __FILE__ == $PROGRAM_NAME
  require "objspace"
  require "weakref"
  arm = ARGV.fetch(0)
  ENV["LOWRAIL"] = "1"
  path, observer = SealedBuilderCost.install if arm == "provenance"
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
  require File.expand_path("config/environment", Dir.pwd)
  observer&.disable
  raise "delivery absent" if arm == "provenance" && SealedBuilderCost::SERVED != [path]
  SealedBuilderCost::ACTIVE[0] = true
  class ProvenanceView
    include ActionView::Helpers::TagHelper
  end
  builder_class = ActionView::Helpers::TagHelper::TagBuilder
  metadata = ->(method) {
    {owner: method.owner.name, name: method.name, original_name: method.original_name,
      source_location: method.source_location, parameters: method.parameters, arity: method.arity}
  }
  info = {new: metadata.call(builder_class.method(:new)),
    initialize: metadata.call(builder_class.instance_method(:initialize)),
    factory: metadata.call(ProvenanceView.instance_method(:tag_builder))}
  constructor_trace = []
  trace = TracePoint.new(:call, :return, :c_call, :c_return) do |event|
    next unless event.method_id == :new && event.self.equal?(builder_class) ||
      event.method_id == :initialize && event.defined_class.equal?(builder_class)
    constructor_trace << [event.event, event.method_id, event.path, event.lineno]
  end
  view = ProvenanceView.new
  builder = nil
  trace.enable { builder = view.send(:tag_builder) }
  info[:constructor_trace] = constructor_trace
  info[:cached_same] = builder.equal?(view.send(:tag_builder))
  info[:view_context_same] = builder.instance_variable_get(:@view_context).equal?(view)
  info[:no_singleton_class] = JSON.parse(ObjectSpace.dump(builder)).fetch("class") ==
    JSON.parse(ObjectSpace.dump(builder_class)).fetch("address")
  info[:exception] = begin
    builder_class.new
    nil
  rescue ArgumentError => error
    [error.class.name, error.message, error.backtrace_locations.select { _1.path.end_with?("tag_helper.rb") }.map { [_1.lineno, _1.label] }]
  end
  info[:threads] = Array.new(4) do
    Thread.new do
      50.times.all? do
        context = ProvenanceView.new
        object = context.send(:tag_builder)
        object.instance_variable_get(:@view_context).equal?(context) &&
          (arm != "provenance" || SealedBuilderCost::BUILDERS.key?(object))
      end
    end
  end.map(&:value)
  info[:ractor] = Ractor.new do
    context = ProvenanceView.new
    object = context.send(:tag_builder)
    [object.class.name, object.instance_variable_get(:@view_context).equal?(context)]
  end.value
  weak = Array.new(100) { WeakRef.new(ProvenanceView.new.send(:tag_builder)) }
  3.times { GC.start }
  info[:collected] = weak.count { !_1.weakref_alive? }
  raise "weak map retains builders" unless info[:collected] == 100
  puts JSON.generate(metadata: info, delivered: !!observer,
    registered: SealedBuilderCost::BUILDERS.key?(builder),
    foreign_refused: !SealedBuilderCost::BUILDERS.key?(builder_class.new(view)))
end
